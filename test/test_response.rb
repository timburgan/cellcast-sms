# frozen_string_literal: true

require "test_helper"

class TestResponse < Minitest::Test
  def test_send_message_response
    raw_response = {
      "message_id" => "msg_123",
      "status" => "queued",
      "cost" => 0.05,
      "parts" => 1
    }

    response = Cellcast::SMS::SendMessageResponse.new(raw_response)

    assert response.success?
    assert_equal "msg_123", response.message_id
    assert_equal "queued", response.status
    assert_equal 0.05, response.cost
    assert_equal 1, response.parts
  end

  def test_bulk_message_response
    raw_response = {
      "messages" => [
        { "message_id" => "msg_1", "status" => "queued", "cost" => 0.05 },
        { "message_id" => "msg_2", "status" => "failed", "cost" => 0.0 },
        { "message_id" => "msg_3", "status" => "queued", "cost" => 0.05 }
      ]
    }

    response = Cellcast::SMS::BulkMessageResponse.new(raw_response)

    assert response.success?
    assert_equal 3, response.total_count
    assert_equal 2, response.successful_count
    assert_equal 1, response.failed_count
    assert_equal 0.10, response.total_cost
  end

  def test_message_status_response
    raw_response = {
      "message_id" => "msg_123",
      "status" => "delivered",
      "delivered_at" => "2023-01-01T12:00:00Z"
    }

    response = Cellcast::SMS::MessageStatusResponse.new(raw_response)

    assert response.success?
    assert response.delivered?
    refute response.failed?
    refute response.pending?
    assert_equal "msg_123", response.message_id
    assert_equal "2023-01-01T12:00:00Z", response.delivered_at
  end

  def test_incoming_message_response
    raw_response = {
      "id" => "inc_123",
      "from" => "+1234567890",
      "to" => "+0987654321",
      "message" => "Hello world",
      "received_at" => "2023-01-01T12:00:00Z",
      "read" => false,
      "original_message_id" => "msg_456"
    }

    response = Cellcast::SMS::IncomingMessageResponse.new(raw_response)

    assert response.success?
    assert_equal "inc_123", response.message_id
    assert_equal "+1234567890", response.from
    assert_equal "+0987654321", response.to
    assert_equal "Hello world", response.message
    refute response.read?
    assert response.is_reply?
    assert_equal "msg_456", response.original_message_id
  end

  def test_incoming_list_response
    raw_response = {
      "data" => [
        { "id" => "inc_1", "from" => "+1111111111", "message" => "Hi", "read" => false },
        { "id" => "inc_2", "from" => "+2222222222", "message" => "Hello", "read" => true },
        { "id" => "inc_3", "from" => "+3333333333", "message" => "Hey", "read" => false }
      ],
      "total" => 3,
      "limit" => 50,
      "offset" => 0
    }

    response = Cellcast::SMS::IncomingListResponse.new(raw_response)

    assert response.success?
    assert_equal 3, response.total
    assert_equal 3, response.items.length
    assert_equal 2, response.unread_count
    refute response.has_more?

    first_message = response.items.first
    assert_instance_of Cellcast::SMS::IncomingMessageResponse, first_message
    assert_equal "inc_1", first_message.message_id
  end

  def test_response_hash_access
    raw_response = { "custom_field" => "custom_value" }
    response = Cellcast::SMS::Response.new(raw_response)

    assert_equal "custom_value", response["custom_field"]
    assert_equal "custom_value", response[:custom_field]
    assert_equal raw_response, response.to_h
  end
end