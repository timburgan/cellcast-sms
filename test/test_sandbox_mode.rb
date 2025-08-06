# frozen_string_literal: true

require "test_helper"

class TestSandboxMode < Minitest::Test
  def setup
    @config = Cellcast::SMS::Configuration.new
    @config.sandbox_mode = true
    @client = Cellcast.sms(api_key: "test_api_key", config: @config)
  end

  def test_sandbox_mode_enabled_in_config
    assert @config.sandbox_mode
    refute Cellcast::SMS::Configuration.new.sandbox_mode # Default is false
  end

  def test_sandbox_success_number
    response = @client.quick_send(to: "+15550000000", message: "Test", from: "TEST")
    assert response.success?
    assert_equal "queued", response.status
    refute_nil response.message_id
    assert response.message_id.start_with?("sandbox_")
    assert_equal 0.05, response.cost
  end

  def test_sandbox_failed_number
    response = @client.quick_send(to: "+15550000001", message: "Test", from: "TEST")
    refute response.success?
    assert_equal "failed", response.status
    assert_equal "Sandbox test failure", response.raw_response['failed_reason']
  end

  def test_sandbox_rate_limit_number
    assert_raises(Cellcast::SMS::RateLimitError) do
      @client.quick_send(to: "+15550000002", message: "Test", from: "TEST")
    end
  end

  def test_sandbox_invalid_number
    assert_raises(Cellcast::SMS::ValidationError) do
      @client.quick_send(to: "+15550000003", message: "Test", from: "TEST")
    end
  end

  def test_sandbox_insufficient_credits_number
    assert_raises(Cellcast::SMS::APIError) do
      @client.quick_send(to: "+15550000004", message: "Test", from: "TEST")
    end
  end

  def test_sandbox_broadcast
    response = @client.broadcast(
      to: ["+15550000000", "+15550000001", "+15551234567"],
      message: "Test broadcast",
      from: "TEST"
    )
    
    assert_equal 3, response.total_count
    assert_equal 2, response.successful_count
    assert_equal 1, response.failed_count
    assert_equal 0.1, response.total_cost
  end

  def test_sandbox_message_status
    status_response = @client.check_status(message_id: "test_delivered_msg")
    assert_equal "test_delivered_msg", status_response.message_id
    assert_equal "delivered", status_response.status
    assert status_response.delivered?
    refute status_response.failed?
    refute status_response.pending?
  end

  def test_sandbox_failed_message_status
    status_response = @client.check_status(message_id: "test_fail_msg")
    assert_equal "test_fail_msg", status_response.message_id
    assert_equal "failed", status_response.status
    refute status_response.delivered?
    assert status_response.failed?
    refute status_response.pending?
  end

  def test_sandbox_pending_message_status
    status_response = @client.check_status(message_id: "test_pending_msg")
    assert_equal "test_pending_msg", status_response.message_id
    assert_equal "sent", status_response.status
    refute status_response.delivered?
    refute status_response.failed?
    assert status_response.pending?
  end

  def test_sandbox_unread_messages
    unread = @client.unread_messages
    assert_equal 1, unread.items.length
    
    message = unread.items.first
    assert_equal "+15551234567", message.from
    assert_equal "Thanks for the update!", message.message
    refute message.read?
    assert message.is_reply?
  end

  def test_sandbox_conversation_history
    history = @client.conversation_history(original_message_id: "test_msg_123")
    assert_equal 1, history.items.length
    
    reply = history.items.first
    assert_equal "test_msg_123", reply.original_message_id
    assert reply.is_reply?
  end

  def test_sandbox_webhook_setup
    response = @client.setup_webhook(
      url: "https://example.com/webhook",
      events: ["sms.delivered", "sms.received"]
    )
    
    assert response.success?
    webhook_data = response.raw_response
    assert_equal "https://example.com/webhook", webhook_data['url']
    assert_equal ["sms.delivered", "sms.received"], webhook_data['events']
    refute_nil webhook_data['webhook_id']
  end

  def test_sandbox_webhook_test
    response = @client.test_webhook
    assert response.success?
    assert response.raw_response['test_sent']
  end

  def test_sandbox_mark_all_read
    response = @client.mark_all_read(message_ids: ["msg1", "msg2"])
    assert response.success?
    assert_equal 2, response.raw_response['marked_read']
  end

  def test_regular_phone_number_defaults_to_success
    response = @client.quick_send(to: "+15551234567", message: "Test", from: "TEST")
    assert response.success?
    assert_equal "queued", response.status
  end

  def test_sandbox_responses_contain_metadata
    response = @client.sms.send_message(to: "+15550000000", message: "Test")
    
    # Verify response structure matches real API
    assert response['id']
    assert response['message_id']
    assert response['to']
    assert response['status']
    assert response['cost']
    assert response['parts']
    assert response['created_at']
  end
end