# frozen_string_literal: true

require "test_helper"

class TestClient < Minitest::Test
  def setup
    @api_key = "test_api_key_123"
    @client = Cellcast.sms(api_key: @api_key)
  end

  def test_client_initialization
    assert_equal @api_key, @client.api_key
    assert_equal "https://api.cellcast.com", @client.base_url
    assert_instance_of Cellcast::SMS::Configuration, @client.config
  end

  def test_client_initialization_with_custom_config
    config = Cellcast::SMS::Configuration.new
    config.open_timeout = 45

    client = Cellcast.sms(api_key: @api_key, config: config)
    assert_equal 45, client.config.open_timeout
  end

  def test_invalid_api_key_raises_validation_error
    error = assert_raises(Cellcast::SMS::ValidationError) do
      Cellcast.sms(api_key: "")
    end

    assert_includes error.message, "API key cannot be nil or empty"
    assert_includes error.message, "https://dashboard.cellcast.com/api-keys"
  end

  def test_nil_api_key_raises_validation_error
    error = assert_raises(Cellcast::SMS::ValidationError) do
      Cellcast.sms(api_key: nil)
    end

    assert_includes error.message, "Get your API key from"
  end

  def test_api_endpoints_accessible
    assert_instance_of Cellcast::SMS::SMSApi, @client.sms
    assert_instance_of Cellcast::SMS::SenderIdApi, @client.sender_id
    assert_instance_of Cellcast::SMS::TokenApi, @client.token
    assert_instance_of Cellcast::SMS::AccountApi, @client.account
  end

  def test_convenience_methods_available
    assert_respond_to @client, :quick_send
    assert_respond_to @client, :broadcast
    assert_respond_to @client, :delivered?
    assert_respond_to @client, :check_status
    assert_respond_to @client, :unread_messages
    assert_respond_to @client, :setup_webhook
  end
end
