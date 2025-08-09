# frozen_string_literal: true

module Cellcast
  module SMS
    # Account API endpoints implementation - only officially documented endpoints
    # Based on official Cellcast API documentation
    class AccountApi
      def initialize(client)
        @client = client
      end

      # Get account balance and details
      # Official endpoint: GET https://api.cellcast.com/api/v1/apiClient/account
      # @return [Hash] API response with account balance and details
      def get_account_balance
        @client.request(method: :get, path: "api/v1/apiClient/account")
      end

      # Get quick API credit usage statistics
      # Official endpoint: GET https://api.cellcast.com/api/v2/report/message/quick-api-credit-usage
      # @return [Hash] API response with usage statistics
      def get_usage_report
        @client.request(method: :get, path: "api/v2/report/message/quick-api-credit-usage")
      end
    end
  end
end