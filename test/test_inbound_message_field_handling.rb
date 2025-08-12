# frozen_string_literal: true

require 'test_helper'

class TestInboundMessageFieldHandling < Minitest::Test
  def test_message_id_field_fallbacks
    # Primary field: message_id
    msg1 = Cellcast::SMS::InboundMessage.new({ 'message_id' => 'primary_123' })
    assert_equal 'primary_123', msg1.message_id

    # Fallback 1: messageId (camelCase)
    msg2 = Cellcast::SMS::InboundMessage.new({ 'messageId' => 'camel_456' })
    assert_equal 'camel_456', msg2.message_id

    # Fallback 2: id
    msg3 = Cellcast::SMS::InboundMessage.new({ 'id' => 'generic_789' })
    assert_equal 'generic_789', msg3.message_id

    # Missing all fields
    msg4 = Cellcast::SMS::InboundMessage.new({})
    assert_nil msg4.message_id
  end

  def test_received_at_field_fallbacks_and_parsing
    # Primary field: received_at
    msg1 = Cellcast::SMS::InboundMessage.new({ 'received_at' => '2025-08-12 16:29:29' })
    assert_kind_of Time, msg1.received_at
    assert_equal 2025, msg1.received_at.year

    # Fallback 1: received_date
    msg2 = Cellcast::SMS::InboundMessage.new({ 'received_date' => '2025-07-15 10:30:45' })
    assert_kind_of Time, msg2.received_at
    assert_equal 7, msg2.received_at.month

    # Fallback 2: date
    msg3 = Cellcast::SMS::InboundMessage.new({ 'date' => '2025-06-20 14:22:33' })
    assert_kind_of Time, msg3.received_at
    assert_equal 6, msg3.received_at.month

    # Invalid date string
    msg4 = Cellcast::SMS::InboundMessage.new({ 'received_at' => 'invalid-date' })
    assert_nil msg4.received_at

    # Missing all date fields
    msg5 = Cellcast::SMS::InboundMessage.new({})
    assert_nil msg5.received_at
  end

  def test_read_status_field_handling
    # Explicit read=true (boolean)
    msg1 = Cellcast::SMS::InboundMessage.new({ 'read' => true })
    assert msg1.read?
    refute msg1.unread?

    # read='1' (string)
    msg2 = Cellcast::SMS::InboundMessage.new({ 'read' => '1' })
    assert msg2.read?
    refute msg2.unread?

    # read=1 (integer)
    msg3 = Cellcast::SMS::InboundMessage.new({ 'read' => 1 })
    assert msg3.read?
    refute msg3.unread?

    # read=false
    msg4 = Cellcast::SMS::InboundMessage.new({ 'read' => false })
    refute msg4.read?
    assert msg4.unread?

    # read='0'
    msg5 = Cellcast::SMS::InboundMessage.new({ 'read' => '0' })
    refute msg5.read?
    assert msg5.unread?

    # Fallback: is_read field
    msg6 = Cellcast::SMS::InboundMessage.new({ 'is_read' => true })
    assert msg6.read?

    # No read field (typical for get-responses endpoint)
    msg7 = Cellcast::SMS::InboundMessage.new({})
    refute msg7.read?  # Defaults to false (unread)
    assert msg7.unread?
  end

  def test_basic_field_access
    data = {
      'from' => '61403309564',
      'body' => 'Test message content',
      'custom_string' => 'custom_value',
      'original_body' => 'Original outbound message',
      'original_message_id' => 'orig-123',
      'subaccount_id' => 'sub_456'
    }

    msg = Cellcast::SMS::InboundMessage.new(data)

    assert_equal '61403309564', msg.from
    assert_equal 'Test message content', msg.body
  end

  def test_missing_basic_fields
    msg = Cellcast::SMS::InboundMessage.new({})

    assert_nil msg.from
    assert_nil msg.body
  end

  def test_hash_like_access
    data = {
      'from' => '61403309564',
      'custom_field' => 'custom_value'
    }

    msg = Cellcast::SMS::InboundMessage.new(data)

    # Hash-like access
    assert_equal '61403309564', msg['from']
    assert_equal 'custom_value', msg['custom_field']
    assert_nil msg['nonexistent']
  end

  def test_to_h_and_to_hash_methods
    data = {
      'from' => '61403309564',
      'body' => 'Test message'
    }

    msg = Cellcast::SMS::InboundMessage.new(data)

    assert_equal data, msg.to_h
    assert_equal data, msg.to_hash
  end

  def test_string_representation
    data = {
      'from' => '61403309564',
      'body' => 'Hello world',
      'read' => false
    }

    msg = Cellcast::SMS::InboundMessage.new(data)
    str = msg.to_s

    assert_includes str, 'InboundMessage'
    assert_includes str, '61403309564'
    assert_includes str, 'Hello world'
    assert_includes str, 'false'
  end

  def test_no_to_field_assumption
    # Inbound messages should NOT have a 'to' field
    # They are replies TO your system, so 'to' doesn't make sense

    data = {
      'from' => '61403309564',
      'body' => 'Reply message'
      # No 'to' field
    }

    msg = Cellcast::SMS::InboundMessage.new(data)

    # Should not have a 'to' accessor method
    refute_respond_to msg, :to
    
    # Hash access should return nil for 'to'
    assert_nil msg['to']
  end

  def test_time_zone_handling_in_received_at
    # Test with timezone info
    msg1 = Cellcast::SMS::InboundMessage.new({ 
      'received_at' => '2025-08-12 16:29:29 +1000' 
    })
    assert_kind_of Time, msg1.received_at

    # Test without timezone (should still parse)
    msg2 = Cellcast::SMS::InboundMessage.new({ 
      'received_at' => '2025-08-12 16:29:29' 
    })
    assert_kind_of Time, msg2.received_at

    # Test ISO format
    msg3 = Cellcast::SMS::InboundMessage.new({ 
      'received_at' => '2025-08-12T16:29:29Z' 
    })
    assert_kind_of Time, msg3.received_at
  end

  def test_field_priority_when_multiple_present
    # When multiple fallback fields are present, should use primary
    data = {
      'message_id' => 'primary',
      'messageId' => 'fallback1',
      'id' => 'fallback2',
      'received_at' => '2025-08-12 16:29:29',
      'received_date' => '2025-07-01 10:00:00',
      'date' => '2025-06-01 10:00:00'
    }

    msg = Cellcast::SMS::InboundMessage.new(data)

    assert_equal 'primary', msg.message_id
    assert_equal 8, msg.received_at.month  # Should use received_at, not fallbacks
  end
end
