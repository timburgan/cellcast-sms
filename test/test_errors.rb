# frozen_string_literal: true

require "test_helper"

class TestErrors < Minitest::Test
  def setup
    config = Cellcast::SMS::Configuration.new
    config.sandbox_mode = true
    @client = Cellcast.sms(api_key: "test_key", config: config)
  end

  def test_validation_error_empty_api_key
    error = assert_raises(Cellcast::SMS::ValidationError) do
      Cellcast.sms(api_key: "")
    end

    assert_includes error.message, "API key cannot be nil or empty"
    assert_includes error.message, "https://dashboard.cellcast.com/api-keys"
  end

  def test_validation_error_nil_api_key
    error = assert_raises(Cellcast::SMS::ValidationError) do
      Cellcast.sms(api_key: nil)
    end

    assert_includes error.message, "API key cannot be nil or empty"
  end

  def test_validation_error_invalid_phone_number
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.send_message(to: "invalid", message: "test")
    end

    assert_includes error.message, "Invalid phone number format"
    assert_includes error.message, "international format"
  end

  def test_validation_error_empty_message
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.send_message(to: "+1234567890", message: "")
    end

    assert_includes error.message, "Message cannot be nil or empty"
  end

  def test_validation_error_message_too_long
    long_message = "x" * 1601 # Over the 1600 character limit

    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.send_message(to: "+1234567890", message: long_message)
    end

    assert_includes error.message, "Message too long"
    assert_includes error.message, "1601/1600"
  end

  def test_rate_limit_error_with_retry_after
    error = assert_raises(Cellcast::SMS::RateLimitError) do
      @client.sms.send_message(to: "+15550000002", message: "test")  # Special test number for rate limiting
    end

    assert_includes error.message, "Rate limit exceeded"
    assert_equal 60, error.retry_after
    assert_equal 429, error.status_code
  end

  def test_validation_error_invalid_test_number
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.send_message(to: "+15550000003", message: "test")  # Special test number for validation error
    end

    assert_includes error.message, "Invalid phone number format"
    assert_includes error.message, "sandbox mode"
  end

  def test_api_error_insufficient_credits
    error = assert_raises(Cellcast::SMS::APIError) do
      @client.sms.send_message(to: "+15550000004", message: "test")  # Special test number for insufficient credits
    end

    assert_includes error.message, "Insufficient credits"
    assert_equal 422, error.status_code
  end

  def test_validation_error_non_string_phone_number
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.send_message(to: 1_234_567_890, message: "test") # Integer instead of string
    end

    assert_includes error.message, "Phone number must be a string"
  end

  def test_validation_error_non_string_message
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.send_message(to: "+1234567890", message: %w[not a string]) # Array instead of string
    end

    assert_includes error.message, "Message must be a string"
  end

  def test_validation_error_invalid_bulk_messages
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.send_bulk(messages: "not an array")
    end

    assert_includes error.message, "Messages must be an array"
  end

  def test_validation_error_empty_bulk_messages
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.send_bulk(messages: [])
    end

    assert_includes error.message, "Messages array cannot be empty"
  end

  def test_validation_error_too_many_bulk_messages
    messages = Array.new(1001) { { to: "+1234567890", message: "test" } }

    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.send_bulk(messages: messages)
    end

    assert_includes error.message, "Too many messages"
  end

  def test_validation_error_invalid_url
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.webhook.configure_webhook(url: "not-a-url", events: ["sms.sent"])
    end

    assert_includes error.message, "URL must be HTTP or HTTPS"
  end

  def test_validation_error_non_https_url
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.webhook.configure_webhook(url: "ftp://example.com", events: ["sms.sent"])
    end

    assert_includes error.message, "URL must be HTTP or HTTPS"
  end

  def test_configuration_validation_negative_timeout
    config = Cellcast::SMS::Configuration.new
    config.open_timeout = -1

    error = assert_raises(Cellcast::SMS::ValidationError) do
      config.validate!
    end

    assert_includes error.message, "open_timeout must be positive"
  end

  def test_error_inheritance
    # Test that our custom errors inherit from the base error
    assert_kind_of Cellcast::SMS::Error, Cellcast::SMS::ValidationError.new("test")
    assert_kind_of Cellcast::SMS::Error, Cellcast::SMS::APIError.new("test")
    assert_kind_of Cellcast::SMS::Error, Cellcast::SMS::RateLimitError.new("test")
    assert_kind_of Cellcast::SMS::Error, Cellcast::SMS::AuthenticationError.new("test")
    assert_kind_of Cellcast::SMS::Error, Cellcast::SMS::ServerError.new("test")
  end
end
