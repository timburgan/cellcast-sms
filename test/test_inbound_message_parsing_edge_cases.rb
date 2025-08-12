# frozen_string_literal: true

require 'test_helper'

class TestInboundMessageParsingEdgeCases < Minitest::Test
  def test_empty_data_responses
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'msg' => 'You have 0 response(s)',
      'data' => {}
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal [], response.messages
    assert_equal 0, response.message_count
    assert_equal nil, response.total_messages
  end

  def test_missing_data_key
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'msg' => 'You have 0 response(s)'
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal [], response.messages
    assert_equal 0, response.message_count
  end

  def test_data_responses_fallback_to_data_data
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'data' => [build_message_hash('123', 'fallback test')]
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal 1, response.messages.length
    assert_equal 'fallback test', response.messages.first.body
  end

  def test_data_responses_fallback_to_messages
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'messages' => [build_message_hash('123', 'messages fallback')]
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal 1, response.messages.length
    assert_equal 'messages fallback', response.messages.first.body
  end

  def test_total_as_string_conversion
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'total' => '15',  # String
        'responses' => []
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal 15, response.total_messages
  end

  def test_total_as_integer
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'total' => 42,  # Integer
        'responses' => []
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal 42, response.total_messages
  end

  def test_total_as_invalid_string
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'total' => 'not-a-number',
        'responses' => []
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal 'not-a-number', response.total_messages
  end

  def test_pagination_with_page_hash
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'page' => { 'count' => 5, 'number' => '3' },
        'responses' => []
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal 3, response.current_page
    assert_equal 5, response.total_pages
  end

  def test_pagination_with_page_integer
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'page' => 2,  # Integer instead of hash
        'responses' => []
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal 2, response.current_page
    assert_equal 1, response.total_pages  # Defaults to 1 when no count
  end

  def test_pagination_with_current_page_integer
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'current_page' => 4,
        'last_page' => 10,
        'responses' => []
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal 4, response.current_page
    assert_equal 10, response.total_pages
  end

  def test_pagination_defaults
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => { 'responses' => [] }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal 1, response.current_page
    assert_equal 1, response.total_pages
  end

  def test_has_more_pages_logic
    # No more pages
    payload1 = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'page' => { 'count' => 3, 'number' => '3' },
        'responses' => []
      }
    }

    response1 = Cellcast::SMS::InboundMessagesResponse.new(payload1)
    refute response1.has_more_pages?
    assert response1.last_page?

    # Has more pages
    payload2 = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'page' => { 'count' => 5, 'number' => '2' },
        'responses' => []
      }
    }

    response2 = Cellcast::SMS::InboundMessagesResponse.new(payload2)
    assert response2.has_more_pages?
    refute response2.last_page?
    refute response2.first_page?
  end

  def test_first_page_detection
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'page' => { 'count' => 5, 'number' => '1' },
        'responses' => []
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert response.first_page?
    assert_equal nil, response.previous_page
    assert_equal 2, response.next_page
  end

  def test_next_and_previous_page_calculations
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'page' => { 'count' => 5, 'number' => '3' },
        'responses' => []
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal 2, response.previous_page
    assert_equal 4, response.next_page
  end

  def test_last_page_next_page_nil
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'page' => { 'count' => 3, 'number' => '3' },
        'responses' => []
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal nil, response.next_page
    assert_equal 2, response.previous_page
  end

  private

  def build_message_hash(id, body)
    {
      'from' => '61403309564',
      'body' => body,
      'received_at' => '2025-08-12 16:29:29',
      'message_id' => id,
      'custom_string' => '',
      'original_body' => 'Original',
      'original_message_id' => 'orig-123',
      'subaccount_id' => ''
    }
  end
end
