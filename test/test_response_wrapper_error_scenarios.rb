# frozen_string_literal: true

require 'test_helper'

class TestResponseWrapperErrorScenarios < Minitest::Test
  def test_api_error_responses
    error_payload = {
      'meta' => { 'status' => 'ERROR', 'code' => 400 },
      'msg' => 'Invalid request parameters'
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(error_payload)
    
    refute response.success?
    assert response.error?
    assert_equal 'Invalid request parameters', response.api_message
    assert_equal 400, response.status_code
    assert_equal [], response.messages  # Should handle gracefully
  end

  def test_authentication_error_response
    auth_error = {
      'meta' => { 'status' => 'ERROR', 'code' => 401 },
      'msg' => 'Invalid API key'
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(auth_error)
    
    refute response.success?
    assert_equal 'Invalid API key', response.api_message
    assert_equal 401, response.status_code
  end

  def test_malformed_meta_section
    # Missing meta section
    payload1 = {
      'msg' => 'Success message',
      'data' => { 'responses' => [] }
    }

    response1 = Cellcast::SMS::InboundMessagesResponse.new(payload1)
    refute response1.success?  # No meta.status = SUCCESS
    assert_equal 'Success message', response1.api_message

    # Meta is not a hash
    payload2 = {
      'meta' => 'not-a-hash',
      'data' => { 'responses' => [] }
    }

    response2 = Cellcast::SMS::InboundMessagesResponse.new(payload2)
    refute response2.success?
  end

  def test_completely_empty_response
    response = Cellcast::SMS::InboundMessagesResponse.new({})
    
    refute response.success?
    assert_nil response.api_message
    assert_nil response.status_code
    assert_equal [], response.messages
    assert_equal 0, response.message_count
    assert_nil response.total_messages
  end

  def test_null_response
    response = Cellcast::SMS::InboundMessagesResponse.new(nil)
    
    # Should not crash, even with nil input
    refute response.success?
    assert_equal [], response.messages
  end

  def test_hash_like_access_with_errors
    error_payload = {
      'meta' => { 'status' => 'ERROR' },
      'msg' => 'Something went wrong',
      'error_details' => 'Detailed error information'
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(error_payload)
    
    # Hash-like access should still work
    assert_equal 'ERROR', response['meta']['status']
    assert_equal 'Something went wrong', response['msg']
    assert_equal 'Detailed error information', response['error_details']
    
    # Dig should work
    assert_equal 'ERROR', response.dig('meta', 'status')
    assert_nil response.dig('nonexistent', 'key')
  end

  def test_iteration_over_error_response
    error_payload = {
      'meta' => { 'status' => 'ERROR' },
      'msg' => 'Error message'
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(error_payload)
    
    # Should be able to iterate like a hash
    keys = []
    response.each { |key, value| keys << key }
    assert_includes keys, 'meta'
    assert_includes keys, 'msg'
  end

  def test_chainable_error_handling
    error_payload = {
      'meta' => { 'status' => 'ERROR' },
      'msg' => 'API Error'
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(error_payload)
    
    success_called = false
    error_called = false
    
    result = response.on_success { |r| success_called = true }
                   .on_error { |r| error_called = true }
    
    refute success_called
    assert error_called
    assert_equal response, result  # Should return self for chaining
  end

  def test_low_balance_alert_handling
    response_with_alert = {
      'meta' => { 'status' => 'SUCCESS' },
      'low_sms_alert' => 'Your SMS balance is running low',
      'data' => { 'responses' => [] }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(response_with_alert)
    
    assert response.low_balance_alert?
    assert_equal 'Your SMS balance is running low', response.low_sms_alert
  end

  def test_string_representation_with_errors
    error_payload = {
      'meta' => { 'status' => 'ERROR' },
      'msg' => 'Authentication failed'
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(error_payload)
    str = response.to_s
    
    assert_includes str, 'InboundMessagesResponse'
    assert_includes str, 'false'  # success: false
    assert_includes str, 'Authentication failed'
  end

  def test_successful_response_chainable_handlers
    success_payload = {
      'meta' => { 'status' => 'SUCCESS' },
      'msg' => 'Messages retrieved',
      'data' => { 'responses' => [] }
    }

    response = Cellcast::SMS::InboundMessagesResponse.new(success_payload)
    
    success_called = false
    error_called = false
    
    result = response.on_success { |r| success_called = true }
                   .on_error { |r| error_called = true }
    
    assert success_called
    refute error_called
    assert_equal response, result
  end
end
