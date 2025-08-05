# frozen_string_literal: true

module Cellcast
  module SMS
    # Retry handler with exponential backoff for robust error handling
    # Handles transient failures, rate limits, and network errors
    module RetryHandler
      # Execute request with retry logic
      # @param config [Configuration] Configuration object
      # @param logger [Logger, nil] Optional logger
      # @yield Block to execute with retry logic
      # @return Result of the yielded block
      def self.with_retries(config:, logger: nil, &block)
        attempt = 0
        begin
          attempt += 1
          block.call
        rescue => error
          if should_retry?(error, attempt, config)
            delay = calculate_delay(attempt, config, error)
            log_retry(logger, error, attempt, delay)
            sleep(delay)
            retry
          else
            raise error
          end
        end
      end

      private

      # Determine if error should trigger a retry
      def self.should_retry?(error, attempt, config)
        return false if attempt > config.max_retries
        
        case error
        when RateLimitError
          config.retry_on_rate_limit
        when ServerError, NetworkError, TimeoutError
          true
        else
          false
        end
      end

      # Calculate exponential backoff delay
      def self.calculate_delay(attempt, config, error)
        base_delay = config.base_delay
        
        # Use retry-after header for rate limits if available
        if error.is_a?(RateLimitError) && error.retry_after
          return [error.retry_after, config.max_delay].min
        end
        
        # Exponential backoff with jitter
        delay = base_delay * (config.backoff_multiplier ** (attempt - 1))
        delay = [delay, config.max_delay].min
        
        # Add jitter (±25% of delay)
        jitter = delay * 0.25 * (rand - 0.5) * 2
        [delay + jitter, 0.1].max
      end

      # Log retry attempt
      def self.log_retry(logger, error, attempt, delay)
        return unless logger
        
        logger.warn(
          "Cellcast API request failed (attempt #{attempt}): #{error.class} - #{error.message}. " \
          "Retrying in #{delay.round(2)} seconds..."
        )
      end
    end
  end
end