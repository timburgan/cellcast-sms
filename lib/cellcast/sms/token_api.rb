# frozen_string_literal: true

module Cellcast
  module SMS
    # Token API endpoints implementation - only officially documented endpoints
    # Based on official Cellcast API documentation
    class TokenApi
      def initialize(client)
        @client = client
      end

      # Verify the current API token
      # Official endpoint: GET https://api.cellcast.com/api/v1/user/token/verify
      # @return [Hash] API response with token verification details
      def verify_token
        @client.request(method: :get, path: "api/v1/user/token/verify")
      end
    end
  end
end
