# frozen_string_literal: true

require_relative "sms/version"
require_relative "sms/errors"
require_relative "sms/configuration"
require_relative "sms/validator"
require_relative "sms/retry_handler"
require_relative "sms/response"
require_relative "sms/sandbox_handler"
require_relative "sms/convenience"
require_relative "sms/client"
require_relative "sms/sms_api"
require_relative "sms/incoming_api"
require_relative "sms/sender_id_api"
require_relative "sms/token_api"
require_relative "sms/webhook_api"

module Cellcast
  module SMS
    # Create a new Cellcast SMS client
    # @param api_key [String] The API key for authentication
    # @param base_url [String] The base URL for the Cellcast API
    # @param config [Configuration] Configuration object for timeouts and retries
    # @return [Cellcast::SMS::Client] A new client instance
    def self.new(api_key:, base_url: "https://api.cellcast.com", config: nil)
      Client.new(api_key: api_key, base_url: base_url, config: config)
    end

    # Create a configuration object with custom settings
    # @yield [Configuration] Configuration object to modify
    # @return [Configuration] Configured object
    def self.configure
      config = Configuration.new
      yield(config) if block_given?
      config.validate!
      config
    end
  end
end
