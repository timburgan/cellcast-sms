# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "openssl"

module Cellcast
  module SMS
    # Main client class for Cellcast SMS API
    # Following Sandi Metz rules: small class with single responsibility
    class Client
      include ConvenienceMethods

      attr_reader :api_key, :base_url, :config

      def initialize(api_key:, base_url: "https://cellcast.com.au/api/v3", config: nil)
        @api_key = validate_api_key(api_key)
        @base_url = base_url.chomp("/")
        @config = config || Configuration.new
        @config.validate!
      end

      # Access to SMS API endpoints
      def sms
        @sms ||= SMSApi.new(self)
      end

      # Access to Sender ID API endpoints (business names and custom numbers)
      def sender_id
        @sender_id ||= SenderIdApi.new(self)
      end

      # Access to Account API endpoints (balance and usage reports)
      def account
        @account ||= AccountApi.new(self)
      end

      # Make HTTP requests to the API with retry logic
      # Following Sandi Metz rule: methods should be small
      def request(method:, path:, body: nil, headers: {})
        # Check if sandbox mode is enabled
        return handle_sandbox_request(method: method, path: path, body: body) if config.sandbox_mode

        RetryHandler.with_retries(logger: config.logger) do
          execute_request(method, path, body, headers)
        end
      end

      private

      def handle_sandbox_request(method:, path:, body: nil)
        @sandbox_handler ||= SandboxHandler.new(logger: config.logger, base_url: base_url)
        @sandbox_handler.handle_request(method: method, path: path, body: body)
      end

      def validate_api_key(key)
        if key.nil? || key.strip.empty?
          raise ValidationError, "API key cannot be nil or empty. Get your API key from https://dashboard.cellcast.com/api-keys"
        end

        key.strip
      end

      def execute_request(method, path, body, headers)
        uri = build_uri(path)
        http = create_http_client(uri)
        request = build_request(method, uri, body, headers)

        response = http.request(request)
        handle_response(response, uri.to_s)
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise TimeoutError, "Request timed out for #{uri}: #{e.message}"
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
        raise ConnectionError, "Connection failed for #{uri}: #{e.message}"
      rescue OpenSSL::SSL::SSLError => e
        raise SSLError, "SSL error for #{uri}: #{e.message}"
      rescue StandardError => e
        raise NetworkError, "Network error for #{uri}: #{e.message}"
      end

      def build_uri(path)
        URI("#{base_url}/#{path.gsub(%r{^/}, '')}")
      end

      def create_http_client(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = config.open_timeout
        http.read_timeout = config.read_timeout
        http
      end

      def build_request(method, uri, body, headers)
        request_class = case method.to_s.upcase
                        when "GET" then Net::HTTP::Get
                        when "POST" then Net::HTTP::Post
                        when "PUT" then Net::HTTP::Put
                        when "DELETE" then Net::HTTP::Delete
                        else raise ValidationError, "Unsupported HTTP method: #{method}"
                        end

        request = request_class.new(uri)
        request["APPKEY"] = api_key
        request["Content-Type"] = "application/json"
        request["Accept"] = "application/json"
        request["User-Agent"] = "cellcast-sms-ruby/#{VERSION}"

        headers.each { |key, value| request[key] = value }
        request.body = body.to_json if body
        request
      end

      def handle_response(response, requested_url)
        case response.code.to_i
        when 200..299
          parse_response_body(response.body)
        when 401
          raise AuthenticationError, "Invalid API key or unauthorized access for #{requested_url}. Please check your API key at https://dashboard.cellcast.com/api-keys"
        when 429
          retry_after = extract_retry_after(response)
          message = "Rate limit exceeded for #{requested_url}. "
          message += retry_after ? "Retry after #{retry_after} seconds." : "Please wait before making more requests."
          raise RateLimitError.new(message,
                                   status_code: response.code.to_i,
                                   response_body: response.body,
                                   requested_url: requested_url,
                                   retry_after: retry_after)
        when 400..499
          error_details = parse_error_details(response.body)
          message = "Client error for #{requested_url}: #{response.message}"
          message += ". #{error_details}" if error_details
          message += ". This may indicate that the API endpoint has changed - please report this issue with the attempted URL."
          raise APIError.new(message,
                             status_code: response.code.to_i,
                             response_body: response.body,
                             requested_url: requested_url)
        when 500..599
          raise ServerError.new("Server error for #{requested_url}: #{response.message}. Please try again later or contact support if the issue persists.",
                                status_code: response.code.to_i,
                                response_body: response.body,
                                requested_url: requested_url)
        else
          raise APIError.new("Unexpected response for #{requested_url}: #{response.code} #{response.message}. This may indicate an API change - please report this issue.",
                             status_code: response.code.to_i,
                             response_body: response.body,
                             requested_url: requested_url)
        end
      end

      def extract_retry_after(response)
        retry_after_header = response["Retry-After"]
        return nil unless retry_after_header

        retry_after_header.to_i if retry_after_header.match?(/^\d+$/)
      end

      def parse_response_body(body)
        return {} if body.nil? || body.strip.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        { "raw_response" => body }
      end

      def parse_error_details(body)
        return nil if body.nil? || body.strip.empty?

        parsed = JSON.parse(body)
        parsed["error"] || parsed["message"] || parsed["detail"]
      rescue JSON::ParserError
        nil
      end
    end
  end
end
