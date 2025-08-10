# frozen_string_literal: true

require "test_helper"

class TestHelperClasses < Minitest::Test
  def setup
    config = Cellcast::SMS::Configuration.new
    config.sandbox_mode = true
    config.response_format = :enhanced
    @client = Cellcast.sms(api_key: "test_key", config: config)
  end

  def test_inbound_message_wrapper
    message_data = {
      'from' => '+1234567890',
      'body' => 'Hello there!',
      'received_date' => '2025-08-10 06:00:00',
      'messageId' => 'inbound_123',
      'read' => '0'
    }
    
    message = Cellcast::SMS::InboundMessage.new(message_data)
    
    assert_equal '+1234567890', message.from
    assert_equal 'Hello there!', message.body
    assert_equal 'inbound_123', message.message_id
    assert message.unread?
    refute message.read?
    assert_instance_of Time, message.received_at
    
    # Test hash-like access
    assert_equal '+1234567890', message['from']
    assert_equal message_data, message.to_h
    
    # Test string representation
    string_repr = message.to_s
    assert_includes string_repr, 'InboundMessage'
    assert_includes string_repr, '+1234567890'
    assert_includes string_repr, 'read: false'
  end

  def test_inbound_message_with_read_status
    read_message_data = {
      'from' => '+1987654321',
      'body' => 'Read message',
      'messageId' => 'read_123',
      'read' => '1'  # Read message
    }
    
    message = Cellcast::SMS::InboundMessage.new(read_message_data)
    assert message.read?
    refute message.unread?
  end

  def test_inbound_message_with_invalid_date
    message_data = {
      'from' => '+1234567890',
      'body' => 'Invalid date test',
      'received_date' => 'invalid-date',
      'messageId' => 'invalid_date_123',
      'read' => '0'
    }
    
    message = Cellcast::SMS::InboundMessage.new(message_data)
    assert_nil message.received_at  # Should handle invalid date gracefully
  end

  def test_bulk_response_collection
    # Create mock responses
    response1_data = {
      'meta' => { 'status' => 'SUCCESS', 'code' => 200 },
      'msg' => 'Queued',
      'data' => {
        'total_numbers' => 10,
        'success_number' => 10,
        'credits_used' => 10,
        'messages' => (1..10).map { |i| { 'message_id' => "msg_#{i}" } }
      }
    }
    
    response2_data = {
      'meta' => { 'status' => 'SUCCESS', 'code' => 200 },
      'msg' => 'Queued',
      'data' => {
        'total_numbers' => 5,
        'success_number' => 3,
        'credits_used' => 3,
        'messages' => (1..3).map { |i| { 'message_id' => "msg2_#{i}" } }
      }
    }
    
    response1 = Cellcast::SMS::BulkSmsResponse.new(response1_data)
    response2 = Cellcast::SMS::BulkSmsResponse.new(response2_data)
    
    collection = Cellcast::SMS::BulkResponseCollection.new([response1, response2])
    
    assert_equal 2, collection.response_count
    assert_equal 15, collection.total_numbers
    assert_equal 13, collection.total_success_number
    assert_equal 2, collection.total_failed_number
    assert_equal 13, collection.total_credits_used
    assert_equal 86.67, collection.success_rate
    refute collection.all_successful?
    
    # Test iteration
    response_count = 0
    collection.each { response_count += 1 }
    assert_equal 2, response_count
    
    # Test message aggregation
    all_messages = collection.all_messages
    assert_equal 13, all_messages.length  # 10 + 3 successful messages
    
    # Test chainable operations
    success_called = false
    error_called = false
    
    collection.on_success { success_called = true }
              .on_error { error_called = true }
    
    refute success_called  # Should not call success since not all successful
    assert error_called    # Should call error since some failed
    
    # Test string representation
    string_repr = collection.to_s
    assert_includes string_repr, 'BulkResponseCollection'
    assert_includes string_repr, '2 responses'
    assert_includes string_repr, '15 total numbers'
    assert_includes string_repr, '86.67% success rate'
  end

  def test_bulk_response_collection_all_successful
    response_data = {
      'meta' => { 'status' => 'SUCCESS', 'code' => 200 },
      'msg' => 'Queued',
      'data' => {
        'total_numbers' => 5,
        'success_number' => 5,
        'credits_used' => 5,
        'messages' => (1..5).map { |i| { 'message_id' => "msg_#{i}" } }
      }
    }
    
    response = Cellcast::SMS::BulkSmsResponse.new(response_data)
    collection = Cellcast::SMS::BulkResponseCollection.new([response])
    
    assert collection.all_successful?
    assert_equal 100.0, collection.success_rate
    assert_equal 0, collection.total_failed_number
    
    # Test chainable operations
    success_called = false
    error_called = false
    
    collection.on_success { success_called = true }
              .on_error { error_called = true }
    
    assert success_called   # Should call success since all successful
    refute error_called     # Should not call error
  end

  def test_templates_response_functionality
    templates_data = {
      'meta' => { 'status' => 'SUCCESS', 'code' => 200 },
      'msg' => 'Templates retrieved',
      'data' => [
        { 'id' => 'template_1', 'name' => 'Welcome Message', 'content' => 'Welcome to our service!' },
        { 'id' => 'template_2', 'name' => 'Reminder', 'content' => 'Don\'t forget about {{event}}' }
      ]
    }
    
    response = Cellcast::SMS::TemplatesResponse.new(templates_data)
    
    assert_equal 2, response.template_count
    assert response.has_templates?
    
    # Test finding templates
    template1 = response.find_template('template_1')
    assert template1
    assert_equal 'Welcome Message', template1['name']
    
    template_by_name = response.find_template('Reminder')
    assert template_by_name
    assert_equal 'template_2', template_by_name['id']
    
    # Test template names
    names = response.template_names
    assert_includes names, 'Welcome Message'
    assert_includes names, 'Reminder'
    
    # Test non-existent template
    assert_nil response.find_template('nonexistent')
  end

  def test_templates_response_empty
    empty_templates_data = {
      'meta' => { 'status' => 'SUCCESS', 'code' => 200 },
      'msg' => 'No templates found',
      'data' => []
    }
    
    response = Cellcast::SMS::TemplatesResponse.new(empty_templates_data)
    
    assert_equal 0, response.template_count
    refute response.has_templates?
    assert_empty response.template_names
    assert_nil response.find_template('any')
  end

  def test_message_details_response
    message_details_data = {
      'meta' => { 'status' => 'SUCCESS', 'code' => 200 },
      'msg' => 'Message found',
      'data' => {
        'message' => {
          'message_id' => 'msg_12345',
          'to' => '+1234567890',
          'message' => 'Test message',
          'from' => 'BRAND',
          'status' => 'delivered',
          'delivered_date' => '2025-08-10 06:30:00'
        }
      }
    }
    
    response = Cellcast::SMS::MessageDetailsResponse.new(message_details_data)
    
    assert response.success?
    assert_equal 'msg_12345', response.message_id
    assert_equal '+1234567890', response.to
    assert_equal 'Test message', response.message_text
    assert_equal 'BRAND', response.from
    assert_equal 'delivered', response.status
    assert response.delivered?
    refute response.failed?
    refute response.pending?
    assert_instance_of Time, response.delivered_at
  end

  def test_registration_response
    registration_data = {
      'meta' => { 'status' => 'SUCCESS', 'code' => 200 },
      'msg' => 'Registration submitted',
      'data' => {
        'id' => 'reg_123',
        'status' => 'pending'
      }
    }
    
    response = Cellcast::SMS::RegistrationResponse.new(registration_data)
    
    assert response.success?
    assert_equal 'reg_123', response.registration_id
    assert_equal 'pending', response.registration_status
    assert response.pending?
    refute response.approved?
    refute response.rejected?
  end

  def test_account_balance_response_enhancements
    balance_data = {
      'meta' => { 'status' => 'SUCCESS', 'code' => 200 },
      'msg' => 'Account balance',
      'data' => {
        'account_name' => 'Test Account',
        'sms_balance' => '5.50',  # Low balance
        'mms_balance' => '50.00'
      }
    }
    
    response = Cellcast::SMS::AccountBalanceResponse.new(balance_data)
    
    assert response.success?
    assert_equal 'Test Account', response.account_name
    assert_equal '5.50', response.sms_balance
    assert_equal '50.00', response.mms_balance
    
    # Test low balance detection
    assert response.low_sms_balance?(10)
    refute response.low_mms_balance?(10)
    assert response.low_balance?(10, 10)
    
    # Test total balance (note: these are strings in the API, so we need to handle that)
    # In a real implementation, we might want to convert to numbers
    assert_equal 55.5, response.total_balance  # This assumes conversion to float
  end
end