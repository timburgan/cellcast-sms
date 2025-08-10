# frozen_string_literal: true

require_relative "cellcast/sms"

# Main Cellcast module providing access to SMS API functionality
module Cellcast
  # Convenience method to create a new SMS client with enhanced configuration
  # @param api_key [String] The API key for authentication
  # @param base_url [String] The base URL for the Cellcast API
  # @param config [Cellcast::SMS::Configuration] Configuration object for timeouts and retries
  # @param response_format [Symbol] Response format (:enhanced, :raw, :both)
  # @param default_sender_id [String, nil] Default sender ID for all messages
  # @param auto_retry_failed [Boolean] Enable automatic retry on failures
  # @param max_retries [Integer] Maximum retry attempts for failed requests
  # @param chunk_size [Integer] Default chunk size for bulk operations
  # @param low_balance_threshold [Integer] SMS balance threshold for low balance warnings
  # @param sandbox_mode [Boolean] Enable sandbox mode for testing
  # @return [Cellcast::SMS::Client] A new client instance
  def self.sms(api_key:, base_url: "https://cellcast.com.au/api/v3", config: nil, **options)
    # Create config if not provided
    unless config
      config = SMS::Configuration.new
      
      # Apply options to config
      config.response_format = options[:response_format] if options[:response_format]
      config.default_sender_id = options[:default_sender_id] if options[:default_sender_id]
      config.auto_retry_failed = options[:auto_retry_failed] if options.key?(:auto_retry_failed)
      config.max_retries = options[:max_retries] if options[:max_retries]
      config.chunk_size = options[:chunk_size] if options[:chunk_size]
      config.low_balance_threshold = options[:low_balance_threshold] if options[:low_balance_threshold]
      config.sandbox_mode = options[:sandbox_mode] if options.key?(:sandbox_mode)
      
      config.validate!
    end
    
    SMS.new(api_key: api_key, base_url: base_url, config: config)
  end

  # Create a configuration object with custom settings
  # @yield [Cellcast::SMS::Configuration] Configuration object to modify
  # @return [Cellcast::SMS::Configuration] Configured object
  def self.configure
    SMS.configure { |config| yield(config) if block_given? }
  end

  # Quick setup for enhanced response format (recommended for new projects)
  # @param api_key [String] The API key for authentication
  # @param default_sender_id [String, nil] Default sender ID for all messages
  # @param sandbox_mode [Boolean] Enable sandbox mode for testing
  # @return [Cellcast::SMS::Client] A new client with enhanced responses
  def self.enhanced_sms(api_key:, default_sender_id: nil, sandbox_mode: false)
    sms(
      api_key: api_key,
      response_format: :enhanced,
      default_sender_id: default_sender_id,
      sandbox_mode: sandbox_mode,
      auto_retry_failed: true
    )
  end

  # Quick setup for legacy raw response format
  # @param api_key [String] The API key for authentication
  # @param sandbox_mode [Boolean] Enable sandbox mode for testing
  # @return [Cellcast::SMS::Client] A new client with raw responses
  def self.raw_sms(api_key:, sandbox_mode: false)
    sms(
      api_key: api_key,
      response_format: :raw,
      sandbox_mode: sandbox_mode
    )
  end
end
