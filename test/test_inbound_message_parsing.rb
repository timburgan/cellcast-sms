# frozen_string_literal: true

require 'test_helper'

class TestInboundMessageParsing < Minitest::Test
  def setup
    @client = Cellcast.sms(api_key: 'test_key')
  end

  def test_inbound_response_parsing_with_real_payload_structure
    # Real v3 API payload structure from live testing
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'msg' => 'You have 2 response(s)',
      'data' => {
        'page' => { 'count' => 1, 'number' => '1' },
        'total' => '2',
        'responses' => [
          {
            'from' => '61403309564',
            'body' => 'Test message 1',
            'received_at' => '2025-08-12 16:29:29',
            'custom_string' => '',
            'original_body' => 'Original outbound message',
            'original_message_id' => '9ECD7AEC-C92B-B5F4-8EC8-278F028FEB8B',
            'message_id' => '6351713879',
            'subaccount_id' => ''
          },
          {
            'from' => '61403309564',
            'body' => 'Test message 2',
            'received_at' => '2025-08-12 17:15:45',
            'custom_string' => '',
            'original_body' => 'Another outbound message',
            'original_message_id' => 'B4F8-8EC8-9ECD7AEC-C92B-278F028FEB8B',
            'message_id' => '6351139283',
            'subaccount_id' => ''
          }
        ]
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)

    # Test wrapper methods
    assert response.success?
    assert_equal 'You have 2 response(s)', response.api_message
    assert_equal 2, response.messages.length
    assert_equal 2, response.total_messages
    assert_equal 1, response.current_page
    assert_equal 1, response.total_pages
    assert_equal 2, response.message_count

    # Test individual message parsing
    first_message = response.messages.first
    assert_equal '61403309564', first_message.from
    assert_equal 'Test message 1', first_message.body
    assert_equal '6351713879', first_message.message_id
    assert_kind_of Time, first_message.received_at
    assert_equal false, first_message.read? # get-responses returns unread messages

    second_message = response.messages.last
    assert_equal '61403309564', second_message.from
    assert_equal 'Test message 2', second_message.body
    assert_equal '6351139283', second_message.message_id
    assert_kind_of Time, second_message.received_at
    assert_equal false, second_message.read?

    # Test iteration
    message_ids = []
    response.each_message do |msg|
      message_ids << msg.message_id
    end
    assert_equal ['6351713879', '6351139283'], message_ids
  end

  def test_pagination_edge_cases
    # Test string total conversion
    payload_with_string_total = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'page' => { 'count' => 3, 'number' => '2' },
        'total' => '15',  # String instead of integer
        'responses' => []
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload_with_string_total)
    assert_equal 15, response.total_messages
    assert_equal 2, response.current_page
    assert_equal 3, response.total_pages
  end

  def test_message_field_fallbacks
    # Test fallback field names for received_at and message_id
    payload_with_alt_fields = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'responses' => [
          {
            'from' => '61403309564',
            'body' => 'Test message',
            'received_date' => '2025-08-12 16:29:29',  # Fallback field name
            'messageId' => '6351713879'  # Alternative camelCase
          }
        ]
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload_with_alt_fields)
    message = response.messages.first
    
    assert_equal '6351713879', message.message_id
    assert_kind_of Time, message.received_at
  end

  def test_empty_responses_handling
    payload_empty = {
      'meta' => { 'status' => 'SUCCESS' },
      'msg' => 'You have 0 response(s)',
      'data' => {
        'page' => { 'count' => 1, 'number' => '1' },
        'total' => '0',
        'responses' => []
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload_empty)
    assert response.success?
    assert_equal 0, response.messages.length
    assert_equal 0, response.total_messages
    assert_equal 0, response.message_count
  end
end
