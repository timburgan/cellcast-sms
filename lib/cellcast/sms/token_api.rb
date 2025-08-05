# frozen_string_literal: true

module Cellcast
  module SMS
    # Token API endpoints implementation
    # Following Sandi Metz rules: small focused class
    class TokenApi
      def initialize(client)
        @client = client
      end

      # Verify the current API token
      # @return [Hash] API response with token verification details
      def verify_token
        @client.request(method: :get, path: "auth/verify-token")
      end

      # Get token information including permissions and limits
      # @return [Hash] API response with token details
      def get_token_info
        @client.request(method: :get, path: "auth/token-info")
      end

      # Refresh the API token (if supported)
      # @return [Hash] API response with new token details
      def refresh_token
        @client.request(method: :post, path: "auth/refresh-token")
      end

      # Get token usage statistics
      # @param period [String] Period for statistics ('daily', 'weekly', 'monthly')
      # @return [Hash] API response with usage statistics
      def get_usage_stats(period: 'daily')
        validate_period(period)
        @client.request(method: :get, path: "auth/usage-stats?period=#{period}")
      end

      private

      def validate_period(period)
        valid_periods = %w[daily weekly monthly]
        unless valid_periods.include?(period)
          raise ValidationError, "Period must be one of: #{valid_periods.join(', ')}"
        end
      end
    end
  end
end