# frozen_string_literal: true

module Cellcast
  module SMS
    # Account API endpoints implementation - based on official Cellcast API documentation
    # Base URL: https://cellcast.com.au/api/v3/
    class AccountApi
      def initialize(client)
        @client = client
      end

      # Get account balance and details
      # Official endpoint: GET https://cellcast.com.au/api/v3/account
      # @return [Hash] API response with account balance and details including sms_balance, mms_balance
      def get_account_balance
        @client.request(method: :get, path: "account")
      end

      # Get SMS templates
      # Official endpoint: GET https://cellcast.com.au/api/v3/get-template
      # @return [Hash] API response with available SMS templates
      def get_templates
        @client.request(method: :get, path: "get-template")
      end

      # Get opt-out list
      # Official endpoint: GET https://cellcast.com.au/api/v3/get-optout
      # @return [Hash] API response with opt-out numbers
      def get_optout_list
        @client.request(method: :get, path: "get-optout")
      end
    end
  end
end