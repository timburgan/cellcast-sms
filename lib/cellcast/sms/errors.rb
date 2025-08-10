# frozen_string_literal: true

module Cellcast
  module SMS
    # Base error class for all Cellcast SMS related errors
    class Error < StandardError; end

    # Authentication error for invalid API keys
    class AuthenticationError < Error; end

    # Validation error for invalid input parameters
    class ValidationError < Error; end

    # Network-related errors
    class NetworkError < Error; end
    class TimeoutError < NetworkError; end
    class ConnectionError < NetworkError; end
    class SSLError < NetworkError; end

    # Legacy API error class (maintained for compatibility)
    class APIError < Error
      attr_reader :status_code, :response_body, :requested_url

      def initialize(message, status_code: nil, response_body: nil, requested_url: nil)
        super(message)
        @status_code = status_code
        @response_body = response_body
        @requested_url = requested_url
      end
    end

    # Legacy rate limit error (maintained for compatibility)
    class RateLimitError < APIError
      attr_reader :retry_after

      def initialize(message, status_code: nil, response_body: nil, requested_url: nil, retry_after: nil)
        super(message, status_code: status_code, response_body: response_body, requested_url: requested_url)
        @retry_after = retry_after
      end
    end

    # Legacy server error (maintained for compatibility)
    class ServerError < APIError; end

    # Structured API error with detailed information
    class CellcastApiError < Error
      attr_reader :response, :status_code, :api_message, :raw_response

      def initialize(response)
        @raw_response = response
        @response = response.is_a?(Hash) ? response : {}
        @status_code = @response.dig('meta', 'code') || 
                      (response.respond_to?(:status_code) ? response.status_code : nil)
        @api_message = @response['msg'] || 
                      (response.respond_to?(:api_message) ? response.api_message : 'Unknown error')
        
        super(build_error_message)
      end

      # Check if error is due to insufficient credit
      def insufficient_credit?
        api_message&.include?('insufficient') || 
        api_message&.include?('balance') ||
        status_code == 402
      end

      # Check if error is due to invalid number format
      def invalid_number?
        api_message&.include?('invalid number') || 
        api_message&.include?('invalid phone') ||
        status_code == 400
      end

      # Check if error is due to rate limiting
      def rate_limited?
        status_code == 429 || api_message&.include?('rate limit')
      end

      # Check if error is due to authentication issues
      def authentication_error?
        status_code == 401 || status_code == 403 ||
        api_message&.include?('unauthorized') ||
        api_message&.include?('invalid api key')
      end

      # Check if error is due to server issues (retryable)
      def server_error?
        status_code && status_code >= 500
      end

      # Check if this error is retryable
      def retryable?
        rate_limited? || server_error?
      end

      # Get suggested retry delay in seconds
      def suggested_retry_delay
        case
        when rate_limited?
          30  # Wait longer for rate limits
        when server_error?
          5   # Shorter wait for server errors
        else
          nil # Not retryable
        end
      end

      private

      def build_error_message
        if status_code
          "Cellcast API Error (#{status_code}): #{api_message}"
        else
          "Cellcast API Error: #{api_message}"
        end
      end
    end

    # Error for configuration issues
    class ConfigurationError < Error; end

    # Error for sandbox mode issues
    class SandboxError < Error; end

    # Error for response parsing issues
    class ResponseError < Error; end

    # Error wrapper that provides structured access to API errors
    class ErrorResponse
      attr_reader :raw_response, :status_code, :api_message

      def initialize(response)
        @raw_response = response
        @status_code = response.dig('meta', 'code')
        @api_message = response['msg']
      end

      # Check if this is an error response
      def error?
        status = @raw_response.dig('meta', 'status')
        status != 'SUCCESS'
      end

      # Get error details
      def error_details
        {
          status_code: status_code,
          message: api_message,
          meta: @raw_response['meta'],
          full_response: @raw_response
        }
      end

      # Convert to exception
      def to_exception
        CellcastApiError.new(@raw_response)
      end

      # Raise as exception if this is an error
      def raise_if_error!
        raise to_exception if error?
        self
      end
    end
  end
end
