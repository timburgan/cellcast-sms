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
      attr_reader :api_key, :base_url, :config

      def initialize(api_key:, base_url: "https://api.cellcast.com", config: nil)
        @api_key = validate_api_key(api_key)
        @base_url = base_url.chomp("/")
        @config = config || Configuration.new
        @config.validate!
      end

      # Access to SMS API endpoints
      def sms
        @sms_api ||= SMSApi.new(self)
      end

      # Access to Incoming SMS API endpoints
      def incoming
        @incoming_api ||= IncomingApi.new(self)
      end

      # Access to Sender ID API endpoints  
      def sender_id
        @sender_id_api ||= SenderIdApi.new(self)
      end

      # Access to Token API endpoints
      def token
        @token_api ||= TokenApi.new(self)
      end

      # Access to Webhook API endpoints
      def webhook
        @webhook_api ||= WebhookApi.new(self)
      end

      # Make HTTP requests to the API with retry logic
      # Following Sandi Metz rule: methods should be small
      def request(method:, path:, body: nil, headers: {})
        RetryHandler.with_retries(config: config, logger: config.logger) do
          execute_request(method, path, body, headers)
        end
      end

      private

      def validate_api_key(key)
        raise ValidationError, "API key cannot be nil or empty" if key.nil? || key.strip.empty?
        key.strip
      end

      def execute_request(method, path, body, headers)
        uri = build_uri(path)
        http = create_http_client(uri)
        request = build_request(method, uri, body, headers)
        
        response = http.request(request)
        handle_response(response)
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise TimeoutError, "Request timed out: #{e.message}"
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
        raise ConnectionError, "Connection failed: #{e.message}"
      rescue OpenSSL::SSL::SSLError => e
        raise SSLError, "SSL error: #{e.message}"
      rescue => e
        raise NetworkError, "Network error: #{e.message}"
      end

      def build_uri(path)
        URI("#{base_url}/#{path.gsub(/^\//, '')}")
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
        request["Authorization"] = "Bearer #{api_key}"
        request["Content-Type"] = "application/json"
        request["User-Agent"] = "cellcast-sms-ruby/#{VERSION}"
        
        headers.each { |key, value| request[key] = value }
        request.body = body.to_json if body
        request
      end

      def handle_response(response)
        case response.code.to_i
        when 200..299
          parse_response_body(response.body)
        when 401
          raise AuthenticationError, "Invalid API key or unauthorized access"
        when 429
          retry_after = extract_retry_after(response)
          raise RateLimitError.new("Rate limit exceeded", 
                                  status_code: response.code.to_i,
                                  response_body: response.body,
                                  retry_after: retry_after)
        when 400..499
          raise APIError.new("Client error: #{response.message}",
                            status_code: response.code.to_i,
                            response_body: response.body)
        when 500..599
          raise ServerError.new("Server error: #{response.message}",
                               status_code: response.code.to_i,
                               response_body: response.body)
        else
          raise APIError.new("Unexpected response: #{response.code} #{response.message}",
                            status_code: response.code.to_i,
                            response_body: response.body)
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
    end
  end
end