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
    class RateLimitError < APIError; end
    class ServerError < APIError; end
  end
end