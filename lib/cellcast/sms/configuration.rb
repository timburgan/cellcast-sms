# frozen_string_literal: true

module Cellcast
  module SMS
    # Configuration class for Cellcast SMS gem
    # Provides configurable options for timeouts, retries, and backoff strategies
    class Configuration
      attr_accessor :open_timeout, :read_timeout, :max_retries, :base_delay,
                    :max_delay, :backoff_multiplier, :retry_on_rate_limit,
                    :logger

      def initialize
        @open_timeout = 30
        @read_timeout = 60  
        @max_retries = 3
        @base_delay = 1.0
        @max_delay = 32.0
        @backoff_multiplier = 2.0
        @retry_on_rate_limit = true
        @logger = nil
      end

      # Validate configuration values
      def validate!
        validate_timeouts
        validate_retry_config
      end

      private

      def validate_timeouts
        raise ValidationError, "open_timeout must be positive" unless open_timeout > 0
        raise ValidationError, "read_timeout must be positive" unless read_timeout > 0
      end

      def validate_retry_config
        unless max_retries >= 0 && max_retries <= 10
          raise ValidationError, "max_retries must be between 0 and 10"
        end
        
        unless base_delay > 0 && base_delay <= 60
          raise ValidationError, "base_delay must be between 0 and 60 seconds"
        end
        
        unless max_delay >= base_delay && max_delay <= 300
          raise ValidationError, "max_delay must be between base_delay and 300 seconds"
        end
      end
    end
  end
end