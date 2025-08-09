# frozen_string_literal: true

module Cellcast
  module SMS
    # Retry handler with exponential backoff for robust error handling
    # Uses sensible hardcoded defaults for reliable operation
    module RetryHandler
      # Hardcoded retry configuration for optimal reliability
      MAX_RETRIES = 3
      BASE_DELAY = 1.0
      MAX_DELAY = 32.0
      BACKOFF_MULTIPLIER = 2.0

      # Execute request with retry logic
      # @param logger [Logger, nil] Optional logger
      # @yield Block to execute with retry logic
      # @return Result of the yielded block
      def self.with_retries(logger: nil, &block)
        attempt = 0
        begin
          attempt += 1
          block.call
        rescue StandardError => e
          raise e unless should_retry?(e, attempt)

          delay = calculate_delay(attempt, e)
          log_retry(logger, e, attempt, delay)
          sleep(delay)
          retry
        end
      end

      # Determine if error should trigger a retry
      def self.should_retry?(error, attempt)
        return false if attempt > MAX_RETRIES

        case error
        when RateLimitError, ServerError, NetworkError, TimeoutError
          true
        else
          false
        end
      end

      # Calculate exponential backoff delay
      def self.calculate_delay(attempt, error)
        # Use retry-after header for rate limits if available
        return [error.retry_after, MAX_DELAY].min if error.is_a?(RateLimitError) && error.retry_after

        # Exponential backoff with jitter
        delay = BASE_DELAY * (BACKOFF_MULTIPLIER**(attempt - 1))
        delay = [delay, MAX_DELAY].min

        # Add jitter (±25% of delay)
        jitter = delay * 0.25 * (rand - 0.5) * 2
        [delay + jitter, 0.1].max
      end

      # Log retry attempt
      def self.log_retry(logger, error, attempt, delay)
        return unless logger

        url_info = error.respond_to?(:requested_url) && error.requested_url ? " (URL: #{error.requested_url})" : ""
        logger.warn(
          "Cellcast API request failed (attempt #{attempt}): #{error.class} - #{error.message}#{url_info}. " \
          "Retrying in #{delay.round(2)} seconds..."
        )
      end
    end
  end
end
