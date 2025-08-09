# frozen_string_literal: true

require "test_helper"

class TestConvenience < Minitest::Test
  def setup
    config = Cellcast::SMS::Configuration.new
    config.sandbox_mode = true
    @client = Cellcast.sms(api_key: "test_key", config: config)
  end

  def test_quick_send
    response = @client.quick_send(
      to: "+1234567890",
      message: "Hello world",
      from: "MyBrand"
    )

    assert_instance_of Cellcast::SMS::SendMessageResponse, response
    assert response.success?
    assert response.message_id
    assert_equal "queued", response.status
  end

  def test_quick_send_special_test_number_success
    response = @client.quick_send(
      to: "+15550000000",
      message: "Hello world",
      from: "MyBrand"
    )

    assert_instance_of Cellcast::SMS::SendMessageResponse, response
    assert response.success?
    assert response.message_id
    assert_equal "queued", response.status
  end

  def test_quick_send_special_test_number_failed
    response = @client.quick_send(
      to: "+15550000001",
      message: "Hello world",
      from: "MyBrand"
    )

    assert_instance_of Cellcast::SMS::SendMessageResponse, response
    refute response.success?
    assert_equal "failed", response.status
  end

  def test_broadcast
    response = @client.broadcast(
      to: ["+1234567890", "+1987654321"],
      message: "Broadcast message",
      from: "MyBrand"
    )

    assert_instance_of Cellcast::SMS::BulkMessageResponse, response
    assert response.success?
    assert_equal 2, response.total_count
    assert_equal 2, response.successful_count
    assert_equal 0, response.failed_count
  end

  def test_broadcast_mixed_results
    response = @client.broadcast(
      to: ["+15550000000", "+15550000001"], # Success + failed
      message: "Broadcast message",
      from: "MyBrand"
    )

    assert_instance_of Cellcast::SMS::BulkMessageResponse, response
    assert response.success?
    assert_equal 2, response.total_count
    assert_equal 1, response.successful_count
    assert_equal 1, response.failed_count
  end

  def test_cancel_message
    # First send a message to get an ID
    send_response = @client.quick_send(to: "+15550000000", message: "Test")
    message_id = send_response.message_id

    response = @client.cancel_message(message_id: message_id)

    assert_instance_of Cellcast::SMS::Response, response
    assert response.success?
  end

  def test_verify_token
    response = @client.verify_token

    assert_instance_of Cellcast::SMS::Response, response
    assert response.success?
  end

  def test_balance
    response = @client.balance

    assert_instance_of Cellcast::SMS::Response, response
    assert response.success?
  end

  def test_usage_report
    response = @client.usage_report

    assert_instance_of Cellcast::SMS::Response, response
    assert response.success?
  end

  def test_register_business
    response = @client.register_business(
      business_name: "Test Business",
      business_registration: "ABN123456789",
      contact_info: { email: "test@example.com", phone: "+1234567890" }
    )

    assert_instance_of Cellcast::SMS::Response, response
    assert response.success?
  end

  def test_register_number
    response = @client.register_number(
      phone_number: "+1234567890",
      purpose: "Customer support"
    )

    assert_instance_of Cellcast::SMS::Response, response
    assert response.success?
  end

  def test_verify_number
    response = @client.verify_number(
      phone_number: "+1234567890",
      verification_code: "123456"
    )

    assert_instance_of Cellcast::SMS::Response, response
    assert response.success?
  end
end
