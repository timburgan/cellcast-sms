# frozen_string_literal: true

require "test_helper"

class TestErrors < Minitest::Test
  def setup
    @client = Cellcast.sms(api_key: "test_key")
  end

  def test_authentication_error_with_helpful_message
    # Mock 401 response
    mock_response = mock_error_response(
      code: 401,
      body: { error: "Invalid API key" }
    )

    # Stub the HTTP request to return 401
    @client.stubs(:request).raises(
      Cellcast::SMS::AuthenticationError.new(
        "Invalid API key or unauthorized access. Please check your API key at https://dashboard.cellcast.com/api-keys"
      )
    )

    error = assert_raises(Cellcast::SMS::AuthenticationError) do
      @client.sms.send_message(to: "+1234567890", message: "test")
    end

    assert_includes error.message, "Invalid API key or unauthorized access"
    assert_includes error.message, "https://dashboard.cellcast.com/api-keys"
  end

  def test_rate_limit_error_with_retry_after
    @client.stubs(:request).raises(
      Cellcast::SMS::RateLimitError.new(
        "Rate limit exceeded. Retry after 60 seconds.",
        status_code: 429,
        retry_after: 60
      )
    )

    error = assert_raises(Cellcast::SMS::RateLimitError) do
      @client.sms.send_message(to: "+1234567890", message: "test")
    end

    assert_includes error.message, "Rate limit exceeded"
    assert_includes error.message, "Retry after 60 seconds"
    assert_equal 60, error.retry_after
    assert_equal 429, error.status_code
  end

  def test_validation_error_for_empty_phone
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.send_message(to: "", message: "test")
    end

    assert_includes error.message, "Phone number cannot be nil or empty"
    assert_includes error.message, "international format"
  end

  def test_validation_error_for_long_message
    long_message = "a" * 1601

    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.send_message(to: "+1234567890", message: long_message)
    end

    assert_includes error.message, "Message too long"
    assert_includes error.message, "1601/1600"
    assert_includes error.message, "splitting into multiple messages"
  end

  def test_validation_error_for_invalid_url
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.webhook.configure_webhook(url: "not-a-url", events: ["sms.sent"])
    end

    assert_includes error.message, "URL must be HTTP or HTTPS"
    assert_includes error.message, "https://yourapp.com/webhooks"
  end

  def test_server_error_with_helpful_message
    @client.stubs(:request).raises(
      Cellcast::SMS::ServerError.new(
        "Server error: Internal Server Error. Please try again later or contact support if the issue persists.",
        status_code: 500
      )
    )

    error = assert_raises(Cellcast::SMS::ServerError) do
      @client.sms.send_message(to: "+1234567890", message: "test")
    end

    assert_includes error.message, "Server error"
    assert_includes error.message, "try again later"
    assert_includes error.message, "contact support"
    assert_equal 500, error.status_code
  end

  def test_api_error_with_details
    @client.stubs(:request).raises(
      Cellcast::SMS::APIError.new(
        "Client error: Bad Request. Invalid phone number format",
        status_code: 400
      )
    )

    error = assert_raises(Cellcast::SMS::APIError) do
      @client.sms.send_message(to: "+1234567890", message: "test")
    end

    assert_includes error.message, "Client error: Bad Request"
    assert_includes error.message, "Invalid phone number format"
    assert_equal 400, error.status_code
  end
end