# frozen_string_literal: true

require "test_helper"

class TestConvenience < Minitest::Test
  def setup
    @client = Cellcast.sms(api_key: "test_key")
  end

  def test_quick_send
    mock_response = mock_successful_response({
      "message_id" => "msg_123",
      "status" => "queued",
      "cost" => 0.05
    })
    
    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    response = @client.quick_send(
      to: "+1234567890",
      message: "Hello world",
      from: "MyBrand"
    )

    assert_instance_of Cellcast::SMS::SendMessageResponse, response
    assert response.success?
    assert_equal "msg_123", response.message_id
    assert_equal "queued", response.status
  end

  def test_broadcast
    mock_response = mock_successful_response({
      "messages" => [
        { "message_id" => "msg_1", "status" => "queued", "cost" => 0.05 },
        { "message_id" => "msg_2", "status" => "queued", "cost" => 0.05 }
      ]
    })
    
    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    response = @client.broadcast(
      to: ["+1234567890", "+0987654321"],
      message: "Broadcast message",
      from: "MyBrand"
    )

    assert_instance_of Cellcast::SMS::BulkMessageResponse, response
    assert response.success?
    assert_equal 2, response.total_count
    assert_equal 2, response.successful_count
    assert_equal 0, response.failed_count
  end

  def test_delivered_true
    mock_response = mock_successful_response({
      "message_id" => "msg_123",
      "status" => "delivered"
    })
    
    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    assert @client.delivered?(message_id: "msg_123")
  end

  def test_delivered_false
    mock_response = mock_successful_response({
      "message_id" => "msg_123",
      "status" => "failed"
    })
    
    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    refute @client.delivered?(message_id: "msg_123")
  end

  def test_check_status
    mock_response = mock_successful_response({
      "message_id" => "msg_123",
      "status" => "delivered",
      "delivered_at" => "2023-01-01T12:00:00Z"
    })
    
    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    response = @client.check_status(message_id: "msg_123")

    assert_instance_of Cellcast::SMS::MessageStatusResponse, response
    assert response.delivered?
    assert_equal "2023-01-01T12:00:00Z", response.delivered_at
  end

  def test_unread_messages
    mock_response = mock_successful_response({
      "data" => [
        { "id" => "inc_1", "from" => "+1111111111", "message" => "Hi", "read" => false },
        { "id" => "inc_2", "from" => "+2222222222", "message" => "Hello", "read" => false }
      ],
      "total" => 2
    })
    
    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    response = @client.unread_messages(limit: 10)

    assert_instance_of Cellcast::SMS::IncomingListResponse, response
    assert_equal 2, response.total
    assert_equal 2, response.unread_count
  end

  def test_setup_webhook
    mock_response = mock_successful_response({
      "webhook_id" => "hook_123",
      "url" => "https://example.com/webhook",
      "events" => ["sms.sent", "sms.delivered", "sms.failed", "sms.received", "sms.reply"]
    })
    
    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    response = @client.setup_webhook(url: "https://example.com/webhook")

    assert_instance_of Cellcast::SMS::Response, response
    assert response.success?
    assert_equal "hook_123", response["webhook_id"]
  end

  def test_setup_webhook_with_custom_events
    mock_response = mock_successful_response({
      "webhook_id" => "hook_123",
      "url" => "https://example.com/webhook",
      "events" => ["sms.sent", "sms.delivered"]
    })
    
    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    response = @client.setup_webhook(
      url: "https://example.com/webhook",
      events: ["sms.sent", "sms.delivered"]
    )

    assert response.success?
    assert_equal ["sms.sent", "sms.delivered"], response["events"]
  end
end