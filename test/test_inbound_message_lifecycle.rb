# frozen_string_literal: true

require 'test_helper'

class TestInboundMessageLifecycle < Minitest::Test
  def setup
    @client = Cellcast.sms(api_key: 'test_key')
  end

  def test_get_inbound_messages_does_not_auto_mark_as_read
    # Simulate API behavior: same response returned multiple times
    api_response = {
      'meta' => { 'status' => 'SUCCESS' },
      'msg' => 'You have 2 response(s)',
      'data' => {
        'page' => { 'count' => 1, 'number' => '1' },
        'total' => '2',
        'responses' => [
          build_message_data('6351713879', 'First message'),
          build_message_data('6351139283', 'Second message')
        ]
      }
    }

    # Mock client to return same response multiple times
    @client.stub :request, api_response do
      first_call = @client.get_inbound_messages
      second_call = @client.get_inbound_messages
      
      # Should return identical results
      assert_equal first_call.messages.length, second_call.messages.length
      assert_equal first_call.total_messages, second_call.total_messages
      
      first_ids = first_call.messages.map(&:message_id).sort
      second_ids = second_call.messages.map(&:message_id).sort
      assert_equal first_ids, second_ids
    end
  end

  def test_explicit_mark_as_read_removes_messages
    # First call returns 2 messages
    initial_response = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'responses' => [
          build_message_data('6351713879', 'First message'),
          build_message_data('6351139283', 'Second message')
        ]
      }
    }

    # After marking one as read, only one remains
    after_mark_response = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => {
        'responses' => [
          build_message_data('6351139283', 'Second message')
        ]
      }
    }

    mark_read_response = {
      'meta' => { 'status' => 'SUCCESS' },
      'msg' => 'Inbound messages have been marked as read.'
    }

    call_count = 0
    @client.stub :request, lambda { |**args|
      call_count += 1
      case call_count
      when 1
        initial_response
      when 2
        mark_read_response
      when 3
        after_mark_response
      end
    } do
      # Get initial messages
      messages = @client.get_inbound_messages
      assert_equal 2, messages.messages.length

      # Mark one as read
      result = @client.mark_message_read(message_id: '6351713879')
      assert_equal 'Inbound messages have been marked as read.', result['msg']

      # Check remaining messages
      remaining = @client.get_inbound_messages
      assert_equal 1, remaining.messages.length
      assert_equal '6351139283', remaining.messages.first.message_id
    end
  end

  def test_mark_all_read_clears_all_messages
    initial_response = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => { 'responses' => [build_message_data('123', 'test')] }
    }

    empty_response = {
      'meta' => { 'status' => 'SUCCESS' },
      'data' => { 'responses' => [] }
    }

    mark_response = { 'meta' => { 'status' => 'SUCCESS' } }

    responses = [initial_response, mark_response, empty_response]
    call_count = 0

    @client.stub :request, lambda { |**args| call_count += 1; responses[call_count - 1] } do
      # Initial messages
      messages = @client.get_inbound_messages
      assert_equal 1, messages.messages.length

      # Mark all as read
      @client.mark_all_read

      # Should be empty now
      remaining = @client.get_inbound_messages
      assert_equal 0, remaining.messages.length
    end
  end

  def test_mark_messages_read_with_message_ids
    mark_response = { 'meta' => { 'status' => 'SUCCESS' } }
    
    @client.stub :request, mark_response do
      result = @client.mark_messages_read(message_ids: ['123', '456'])
      assert_equal 'SUCCESS', result.dig('meta', 'status')
    end
  end

  def test_mark_messages_read_with_timestamp
    mark_response = { 'meta' => { 'status' => 'SUCCESS' } }
    
    @client.stub :request, mark_response do
      result = @client.mark_messages_read(before: Time.now)
      assert_equal 'SUCCESS', result.dig('meta', 'status')
    end
  end

  private

  def build_message_data(id, body)
    {
      'from' => '61403309564',
      'body' => body,
      'received_at' => '2025-08-12 16:29:29',
      'message_id' => id,
      'custom_string' => '',
      'original_body' => 'Original message',
      'original_message_id' => 'orig-123',
      'subaccount_id' => ''
    }
  end
end
