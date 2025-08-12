# frozen_string_literal: true

require 'test_helper'

class TestConvenienceMethodsLifecycle < Minitest::Test
  def setup
    @client = Cellcast.sms(api_key: 'test_key')
  end

  def test_mark_message_read_single
    expected_request = { message_id: '123456' }
    api_response = { 'meta' => { 'status' => 'SUCCESS' }, 'msg' => 'Message marked as read' }
    
    @client.stub :request, lambda { |**args|
      assert_equal :post, args[:method]
      assert_equal 'inbound-read', args[:path]
      assert_equal expected_request, args[:body]
      api_response
    } do
      result = @client.mark_message_read(message_id: '123456')
      assert_equal 'Message marked as read', result['msg']
    end
  end

  def test_mark_messages_read_with_array
    message_ids = ['123', '456', '789']
    api_response = { 'meta' => { 'status' => 'SUCCESS' } }
    
    call_count = 0
    @client.stub :request, lambda { |**args|
      call_count += 1
      expected_id = message_ids[call_count - 1]
      assert_equal :post, args[:method]
      assert_equal 'inbound-read', args[:path]
      assert_equal({ message_id: expected_id }, args[:body])
      api_response
    } do
      result = @client.mark_messages_read(message_ids: message_ids)
      assert_equal 3, call_count
      assert_equal 'SUCCESS', result.dig('meta', 'status')
    end
  end

  def test_mark_messages_read_with_timestamp
    timestamp = Time.parse('2025-08-12 10:00:00')
    expected_body = { timestamp: timestamp.iso8601 }
    api_response = { 'meta' => { 'status' => 'SUCCESS' } }
    
    @client.stub :request, lambda { |**args|
      assert_equal :post, args[:method]
      assert_equal 'inbound-read-bulk', args[:path]
      assert_equal expected_body, args[:body]
      api_response
    } do
      result = @client.mark_messages_read(before: timestamp)
      assert_equal 'SUCCESS', result.dig('meta', 'status')
    end
  end

  def test_mark_messages_read_with_string_timestamp
    timestamp_string = '2025-08-12T10:00:00Z'
    expected_body = { timestamp: timestamp_string }
    api_response = { 'meta' => { 'status' => 'SUCCESS' } }
    
    @client.stub :request, lambda { |**args|
      assert_equal expected_body, args[:body]
      api_response
    } do
      result = @client.mark_messages_read(before: timestamp_string)
      assert_equal 'SUCCESS', result.dig('meta', 'status')
    end
  end

  def test_mark_messages_read_all_current
    expected_body = {}  # No timestamp = mark all current
    api_response = { 'meta' => { 'status' => 'SUCCESS' } }
    
    @client.stub :request, lambda { |**args|
      assert_equal :post, args[:method]
      assert_equal 'inbound-read-bulk', args[:path]
      assert_equal expected_body, args[:body]
      api_response
    } do
      result = @client.mark_messages_read
      assert_equal 'SUCCESS', result.dig('meta', 'status')
    end
  end

  def test_mark_all_read_without_timestamp
    expected_body = {}
    api_response = { 'meta' => { 'status' => 'SUCCESS' } }
    
    @client.stub :request, lambda { |**args|
      assert_equal expected_body, args[:body]
      api_response
    } do
      result = @client.mark_all_read
      assert_equal 'SUCCESS', result.dig('meta', 'status')
    end
  end

  def test_mark_all_read_with_timestamp
    timestamp = Time.parse('2025-08-12 10:00:00')
    expected_body = { timestamp: timestamp.iso8601 }
    api_response = { 'meta' => { 'status' => 'SUCCESS' } }
    
    @client.stub :request, lambda { |**args|
      assert_equal expected_body, args[:body]
      api_response
    } do
      result = @client.mark_all_read(before: timestamp)
      assert_equal 'SUCCESS', result.dig('meta', 'status')
    end
  end

  def test_get_inbound_messages_enhanced_response_wrapping
    api_response = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'responses' => [
          {
            'from' => '61403309564',
            'body' => 'Test message',
            'message_id' => '123',
            'received_at' => '2025-08-12 16:29:29'
          }
        ]
      }
    }

    @client.stub :request, api_response do
      result = @client.get_inbound_messages(page: 1)
      
      # Should return wrapped response, not raw hash
      assert_kind_of Cellcast::SMS::InboundMessagesResponse, result
      assert result.success?
      assert_equal 1, result.messages.length
      
      message = result.messages.first
      assert_kind_of Cellcast::SMS::InboundMessage, message
      assert_equal '61403309564', message.from
      assert_equal 'Test message', message.body
    end
  end

  def test_error_handling_in_lifecycle_methods
    error_response = {
      'meta' => { 'status' => 'ERROR', 'code' => 400 },
      'msg' => 'Invalid message ID'
    }
    
    @client.stub :request, error_response do
      result = @client.mark_message_read(message_id: 'invalid')
      assert_equal 'ERROR', result.dig('meta', 'status')
      assert_equal 'Invalid message ID', result['msg']
    end
  end

  def test_empty_message_ids_array
    # Should not make any API calls for empty array
    call_count = 0
    @client.stub :request, lambda { |**args| call_count += 1; {} } do
      result = @client.mark_messages_read(message_ids: [])
      assert_equal 0, call_count
      assert_nil result  # No API call made
    end
  end

  def test_mixed_parameters_priority
    # When both message_ids and before are provided, should prefer message_ids
    message_ids = ['123']
    timestamp = Time.now
    api_response = { 'meta' => { 'status' => 'SUCCESS' } }
    
    @client.stub :request, lambda { |**args|
      # Should call individual message marking, not bulk
      assert_equal 'inbound-read', args[:path]
      api_response
    } do
      result = @client.mark_messages_read(message_ids: message_ids, before: timestamp)
      assert_equal 'SUCCESS', result.dig('meta', 'status')
    end
  end
end
