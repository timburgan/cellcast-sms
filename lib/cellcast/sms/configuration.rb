# frozen_string_literal: true

module Cellcast
  module SMS
    # Configuration class for Cellcast SMS gem
    # Provides configurable options for timeouts, logging, and response handling
    class Configuration
      attr_accessor :open_timeout, :read_timeout, :logger, :sandbox_mode, 
                    :response_format, :default_sender_id, :auto_retry_failed,
                    :max_retries, :retry_delay, :chunk_size, :low_balance_threshold

      # Available response formats
      RESPONSE_FORMATS = [:enhanced, :raw, :both].freeze

      def initialize
        @open_timeout = 30
        @read_timeout = 60
        @logger = nil
        @sandbox_mode = false
        @response_format = :enhanced  # Default to enhanced responses (no backward compatibility needed)
        @default_sender_id = nil
        @auto_retry_failed = true
        @max_retries = 3
        @retry_delay = 2  # Base delay for exponential backoff
        @chunk_size = 100  # Default chunk size for bulk operations
        @low_balance_threshold = 10  # Default low balance threshold for SMS
      end

      # Validate configuration values
      def validate!
        validate_timeouts
        validate_response_format
        validate_retry_settings
        validate_chunk_size
      end

      # Check if enhanced responses should be used
      def enhanced_responses?
        @response_format == :enhanced || @response_format == :both
      end

      # Check if raw responses should be preserved
      def preserve_raw_responses?
        @response_format == :raw || @response_format == :both
      end

      # Get retry delay for attempt number (exponential backoff)
      def retry_delay_for_attempt(attempt)
        @retry_delay ** attempt
      end

      private

      def validate_timeouts
        raise ValidationError, "open_timeout must be positive" unless open_timeout.positive?
        raise ValidationError, "read_timeout must be positive" unless read_timeout.positive?
      end

      def validate_response_format
        unless RESPONSE_FORMATS.include?(@response_format)
          raise ValidationError, "response_format must be one of: #{RESPONSE_FORMATS.join(', ')}"
        end
      end

      def validate_retry_settings
        raise ValidationError, "max_retries must be non-negative" unless max_retries >= 0
        raise ValidationError, "retry_delay must be positive" unless retry_delay.positive?
      end

      def validate_chunk_size
        raise ValidationError, "chunk_size must be positive" unless chunk_size.positive?
      end
    end
  end
end
