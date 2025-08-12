# frozen_string_literal: true

require 'test_helper'

class TestInboundMessageBoundaryConditions < Minitest::Test
  def test_extremely_large_message_counts
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'total' => '999999999',
        'page' => { 'count' => 50000, 'number' => '25000' },
        'responses' => []
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal 999999999, response.total_messages
    assert_equal 25000, response.current_page
    assert_equal 50000, response.total_pages
  end

  def test_zero_page_numbers
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'page' => { 'count' => 0, 'number' => '0' },
        'responses' => []
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal 0, response.current_page
    assert_equal 0, response.total_pages
    refute response.has_more_pages?
  end

  def test_negative_page_numbers
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'page' => { 'count' => -1, 'number' => '-1' },
        'responses' => []
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    # Should handle gracefully, even if nonsensical
    assert_equal(-1, response.current_page)
    assert_equal(-1, response.total_pages)
  end

  def test_extremely_long_message_content
    long_message = 'A' * 10000  # Very long message

    data = {
      'from' => '61403309564',
      'body' => long_message,
      'message_id' => '123'
    }

    msg = Cellcast::SMS::InboundMessage.new(data)
    assert_equal long_message, msg.body
    assert_equal 10000, msg.body.length
  end

  def test_unicode_and_special_characters
    unicode_message = "Hello 👋 世界 🌍 café naïve résumé"
    
    data = {
      'from' => '+33612345678',
      'body' => unicode_message,
      'message_id' => 'unicode_123'
    }

    msg = Cellcast::SMS::InboundMessage.new(data)
    assert_equal unicode_message, msg.body
    assert_equal '+33612345678', msg.from
  end

  def test_empty_string_fields
    data = {
      'from' => '',
      'body' => '',
      'message_id' => '',
      'received_at' => ''
    }

    msg = Cellcast::SMS::InboundMessage.new(data)
    assert_equal '', msg.from
    assert_equal '', msg.body
    assert_equal '', msg.message_id
    assert_nil msg.received_at  # Empty string should not parse as time
  end

  def test_nil_fields
    data = {
      'from' => nil,
      'body' => nil,
      'message_id' => nil,
      'received_at' => nil
    }

    msg = Cellcast::SMS::InboundMessage.new(data)
    assert_nil msg.from
    assert_nil msg.body
    assert_nil msg.message_id
    assert_nil msg.received_at
  end

  def test_numeric_string_message_ids
    # Message IDs that look like numbers but should remain strings
    data = {
      'message_id' => '0000123456789',
      'from' => '61403309564',
      'body' => 'test'
    }

    msg = Cellcast::SMS::InboundMessage.new(data)
    assert_equal '0000123456789', msg.message_id
    assert_kind_of String, msg.message_id
  end

  def test_very_long_phone_numbers
    # Some international numbers can be quite long
    long_number = '+123456789012345678901'
    
    data = {
      'from' => long_number,
      'body' => 'test message'
    }

    msg = Cellcast::SMS::InboundMessage.new(data)
    assert_equal long_number, msg.from
  end

  def test_malformed_date_strings
    malformed_dates = [
      'not-a-date',           # Invalid format
      '2025-13-12 16:29:29',  # Invalid month
      '2025-08-32 16:29:29',  # Invalid day
      '2025-08-12 25:29:29',  # Invalid hour
      'invalid date format',  # Completely invalid
      '16:29:29',             # Time only, no date
      '1234567890',           # Unix timestamp as string
      'tomorrow',             # Relative text
      ''                      # Empty string
    ]

    malformed_dates.each do |bad_date|
      data = { 'received_at' => bad_date }
      msg = Cellcast::SMS::InboundMessage.new(data)
      assert_nil msg.received_at, "Expected nil for malformed date: #{bad_date}"
    end
  end

  def test_edge_case_pagination_calculations
    # Test page 1 of 1
    payload1 = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'page' => { 'count' => 1, 'number' => '1' },
        'responses' => []
      }
    }

    response1 = Cellcast::SMS::InboundMessagesResponse.new(payload1)
    assert response1.first_page?
    assert response1.last_page?
    refute response1.has_more_pages?
    assert_nil response1.next_page
    assert_nil response1.previous_page

    # Test middle page
    payload2 = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'page' => { 'count' => 10, 'number' => '5' },
        'responses' => []
      }
    }

    response2 = Cellcast::SMS::InboundMessagesResponse.new(payload2)
    refute response2.first_page?
    refute response2.last_page?
    assert response2.has_more_pages?
    assert_equal 6, response2.next_page
    assert_equal 4, response2.previous_page
  end

  def test_mixed_data_types_in_response
    # Test when API returns unexpected data types
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'total' => 123.45,  # Float instead of string/int
        'page' => 'not-a-hash',  # String instead of hash
        'responses' => 'not-an-array'  # String instead of array
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    
    # Should handle gracefully
    assert_equal 123.45, response.total_messages
    assert_equal 1, response.current_page  # Default fallback
    assert_equal [], response.messages  # Empty array fallback
  end

  def test_responses_array_with_mixed_valid_invalid_messages
    payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'responses' => [
          # Valid message
          {
            'from' => '61403309564',
            'body' => 'Valid message',
            'message_id' => '123',
            'received_at' => '2025-08-12 16:29:29'
          },
          # Invalid/malformed message
          {
            'from' => nil,
            'body' => '',
            'message_id' => nil,
            'received_at' => 'invalid-date'
          },
          # Minimal message
          {
            'body' => 'Minimal message'
            # Missing other fields
          }
        ]
      }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(payload)
    assert_equal 3, response.messages.length

    # First message should be fully valid
    msg1 = response.messages[0]
    assert_equal '61403309564', msg1.from
    assert_equal 'Valid message', msg1.body
    assert_equal '123', msg1.message_id
    assert_kind_of Time, msg1.received_at

    # Second message should handle nils gracefully
    msg2 = response.messages[1]
    assert_nil msg2.from
    assert_equal '', msg2.body
    assert_nil msg2.message_id
    assert_nil msg2.received_at

    # Third message should handle missing fields
    msg3 = response.messages[2]
    assert_nil msg3.from
    assert_equal 'Minimal message', msg3.body
    assert_nil msg3.message_id
    assert_nil msg3.received_at
  end
end
