# frozen_string_literal: true

module Cellcast
  module SMS
    # Configuration class for Cellcast SMS gem
    # Provides configurable options for timeouts and logging
    class Configuration
      attr_accessor :open_timeout, :read_timeout, :logger

      def initialize
        @open_timeout = 30
        @read_timeout = 60  
        @logger = nil
      end

      # Validate configuration values
      def validate!
        validate_timeouts
      end

      private

      def validate_timeouts
        raise ValidationError, "open_timeout must be positive" unless open_timeout > 0
        raise ValidationError, "read_timeout must be positive" unless read_timeout > 0
      end
    end
  end
end