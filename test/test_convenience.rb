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

  def test_delivered_true
    # First send a message to get an ID
    send_response = @client.quick_send(to: "+15550000000", message: "Test")
    message_id = send_response.message_id

    assert @client.delivered?(message_id: message_id)
  end

  def test_delivered_false
    # Use failed test number message ID
    assert_equal false, @client.delivered?(message_id: "sandbox_fail_123")
  end

  def test_check_status
    # First send a message to get an ID
    send_response = @client.quick_send(to: "+15550000000", message: "Test")
    message_id = send_response.message_id

    status_response = @client.check_status(message_id: message_id)

    assert_instance_of Cellcast::SMS::MessageStatusResponse, status_response
    assert status_response.success?
    assert_equal message_id, status_response.message_id
    assert_includes %w[delivered sent queued], status_response.status
  end

  def test_unread_messages
    response = @client.unread_messages

    assert_instance_of Cellcast::SMS::IncomingListResponse, response
    assert response.success?
    assert response.items.is_a?(Array)
  end

  def test_setup_webhook
    response = @client.setup_webhook(url: "https://example.com/webhook")

    assert_instance_of Cellcast::SMS::Response, response
    assert response.success?
  end

  def test_setup_webhook_with_custom_events
    response = @client.setup_webhook(
      url: "https://example.com/webhook",
      events: ["sms.delivered", "sms.received"]
    )

    assert_instance_of Cellcast::SMS::Response, response
    assert response.success?
  end

  def test_conversation_history
    response = @client.conversation_history(original_message_id: "test_msg_123")

    assert_instance_of Cellcast::SMS::IncomingListResponse, response
    assert response.success?
    assert response.items.is_a?(Array)
  end

  def test_test_webhook
    response = @client.test_webhook

    assert_instance_of Cellcast::SMS::Response, response
    assert response.success?
  end

  def test_mark_all_read
    response = @client.mark_all_read(message_ids: %w[msg1 msg2])

    assert_instance_of Cellcast::SMS::Response, response
    assert response.success?
  end
end
