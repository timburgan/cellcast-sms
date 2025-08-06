# frozen_string_literal: true

module Cellcast
  module SMS
    # Custom error classes for Cellcast SMS gem
    class Error < StandardError; end
    class AuthenticationError < Error; end

    class APIError < Error
      attr_reader :status_code, :response_body

      def initialize(message, status_code: nil, response_body: nil)
        super(message)
        @status_code = status_code
        @response_body = response_body
      end
    end

    class ValidationError < Error; end

    class RateLimitError < APIError
      attr_reader :retry_after

      def initialize(message, status_code: nil, response_body: nil, retry_after: nil)
        super(message, status_code: status_code, response_body: response_body)
        @retry_after = retry_after
      end
    end

    class ServerError < APIError; end

    # Network-related errors
    class NetworkError < Error; end
    class TimeoutError < NetworkError; end
    class ConnectionError < NetworkError; end
    class SSLError < NetworkError; end
  end
end
