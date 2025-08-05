# frozen_string_literal: true

require_relative "sms/version"
require_relative "sms/client"
require_relative "sms/sms_api"
require_relative "sms/incoming_api"
require_relative "sms/sender_id_api"
require_relative "sms/token_api"
require_relative "sms/webhook_api"
require_relative "sms/errors"

module Cellcast
  module SMS
    # Create a new Cellcast SMS client
    # @param api_key [String] The API key for authentication
    # @param base_url [String] The base URL for the Cellcast API
    # @return [Cellcast::SMS::Client] A new client instance
    def self.new(api_key:, base_url: "https://api.cellcast.com")
      Client.new(api_key: api_key, base_url: base_url)
    end
  end
end