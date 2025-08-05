# frozen_string_literal: true

require_relative "cellcast/sms"

# Main Cellcast module providing access to SMS API functionality
module Cellcast
  # Convenience method to create a new SMS client
  # @param api_key [String] The API key for authentication
  # @param base_url [String] The base URL for the Cellcast API
  # @return [Cellcast::SMS::Client] A new client instance
  def self.sms(api_key:, base_url: "https://api.cellcast.com")
    SMS.new(api_key: api_key, base_url: base_url)
  end
end