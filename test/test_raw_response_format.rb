# frozen_string_literal: true

require "test_helper"

class TestRawResponseFormat < Minitest::Test
  def setup
    config = Cellcast::SMS::Configuration.new
    config.sandbox_mode = true
    config.response_format = :raw  # Test raw responses
    @client = Cellcast.sms(api_key: "test_key", config: config)
  end

  def test_raw_quick_send
    response = @client.quick_send(
      to: "+1234567890",
      message: "Hello world",
      from: "MyBrand"
    )

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
    assert response.dig("data", "messages", 0, "message_id"), "Should have message_id"
    assert_equal "Queued", response["msg"]
  end

  def test_raw_broadcast
    response = @client.broadcast(
      to: ["+1234567890", "+1987654321"],
      message: "Broadcast message",
      from: "MyBrand"
    )

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
    assert_equal 2, response.dig("data", "total_numbers")
    assert_equal 2, response.dig("data", "success_number")
    assert_equal 2, response.dig("data", "messages").length
  end

  def test_raw_balance
    response = @client.balance

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
    assert response.dig("data", "sms_balance"), "Should have SMS balance"
    assert response.dig("data", "mms_balance"), "Should have MMS balance"
  end

  def test_raw_get_message_status
    response = @client.get_message_status(message_id: "test_message_123")

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
  end

  def test_raw_get_inbound_messages
    response = @client.get_inbound_messages(page: 1)

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
  end

  def test_raw_responses_no_chainable_methods
    response = @client.quick_send(
      to: "+1234567890",
      message: "No chaining test"
    )

    # Raw responses shouldn't have chainable methods
    refute_respond_to response, :on_success
    refute_respond_to response, :on_error
    refute_respond_to response, :success?
    refute_respond_to response, :message_id
  end
end