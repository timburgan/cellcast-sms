# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "cellcast"
require "minitest/autorun"
require "minitest/pride"

class TestDeleteMessage < Minitest::Test
  def setup
    @config = Cellcast::SMS::Configuration.new
    @config.sandbox_mode = true
    @client = Cellcast.sms(api_key: "test-key", config: @config)
  end

  def test_delete_message_success
    message_id = "sandbox_message_123"
    
    response = @client.sms.delete_message(message_id: message_id)
    
    assert response
    assert_equal "web", response["app_type"]
    assert_equal "1.0", response["app_version"]
    assert_equal true, response["status"]
    assert_equal "Message deleted successfully", response["message"]
    assert_equal message_id, response["data"]["message_id"]
    assert_equal true, response["data"]["deleted"]
    assert response["data"]["deleted_at"]
  end

  def test_delete_message_not_found
    message_id = "sandbox_notfound_123"
    
    error = assert_raises(Cellcast::SMS::APIError) do
      @client.sms.delete_message(message_id: message_id)
    end
    
    assert_equal 404, error.status_code
    assert_includes error.message, "Message not found"
  end

  def test_delete_message_already_sent
    message_id = "sandbox_already_sent_123"
    
    error = assert_raises(Cellcast::SMS::APIError) do
      @client.sms.delete_message(message_id: message_id)
    end
    
    assert_equal 400, error.status_code
    assert_includes error.message, "Cannot delete already sent message"
  end

  def test_delete_message_server_error
    message_id = "sandbox_fail_123"
    
    error = assert_raises(Cellcast::SMS::APIError) do
      @client.sms.delete_message(message_id: message_id)
    end
    
    assert_equal 500, error.status_code
    assert_includes error.message, "Delete operation failed"
  end

  def test_delete_message_validation_empty_id
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.delete_message(message_id: "")
    end
    
    assert_includes error.message, "Message ID cannot be nil or empty"
  end

  def test_delete_message_validation_nil_id
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.delete_message(message_id: nil)
    end
    
    assert_includes error.message, "Message ID cannot be nil or empty"
  end

  def test_delete_message_validation_whitespace_id
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.delete_message(message_id: "   ")
    end
    
    assert_includes error.message, "Message ID cannot be nil or empty"
  end

  def test_delete_message_with_special_characters
    message_id = "sandbox_123_456_abc-def"
    
    response = @client.sms.delete_message(message_id: message_id)
    
    assert response
    assert_equal true, response["status"]
    assert_equal message_id, response["data"]["message_id"]
  end

  def test_convenience_cancel_message_success
    message_id = "sandbox_message_456"
    
    response = @client.cancel_message(message_id: message_id)
    
    assert_instance_of Cellcast::SMS::Response, response
    assert response.success?
    assert_equal "Message deleted successfully", response["message"]
    assert_equal message_id, response["data"]["message_id"]
  end

  def test_convenience_cancel_message_not_found
    message_id = "sandbox_notfound_456"
    
    error = assert_raises(Cellcast::SMS::APIError) do
      @client.cancel_message(message_id: message_id)
    end
    
    assert_equal 404, error.status_code
  end

  def test_delete_message_unicode_id
    # Test with a Unicode message ID (though this is unlikely in practice)
    message_id = "sandbox_message_测试_123"
    
    response = @client.sms.delete_message(message_id: message_id)
    
    assert response
    assert_equal true, response["status"]
    assert_equal message_id, response["data"]["message_id"]
  end

  def test_delete_message_very_long_id
    # Test with a very long message ID
    message_id = "sandbox_" + ("a" * 100)
    
    response = @client.sms.delete_message(message_id: message_id)
    
    assert response
    assert_equal true, response["status"]
    assert_equal message_id, response["data"]["message_id"]
  end

  def test_delete_message_integration_flow
    # Test a realistic workflow: send a scheduled message, then delete it
    
    # First send a scheduled message (this would return a message ID in real usage)
    message_id = "sandbox_scheduled_123"
    
    # Then delete it
    response = @client.sms.delete_message(message_id: message_id)
    
    assert response
    assert_equal true, response["status"]
    assert_equal "Message deleted successfully", response["message"]
    assert_equal message_id, response["data"]["message_id"]
    
    # Verify the response structure matches expected API format
    assert response["app_type"]
    assert response["app_version"]
    assert response.key?("maintainence")
    assert response.key?("status")
    assert response.key?("data")
    assert response.key?("error")
  end

  def test_delete_message_response_structure
    message_id = "sandbox_test_structure"
    
    response = @client.sms.delete_message(message_id: message_id)
    
    # Verify all expected fields are present
    expected_fields = %w[
      app_type app_version maintainence new_version force_update
      invalid_token refresh_token show_message is_enc status
      message message_type data error
    ]
    
    expected_fields.each do |field|
      assert response.key?(field), "Response missing field: #{field}"
    end
    
    # Verify data structure
    assert response["data"].key?("message_id")
    assert response["data"].key?("deleted")
    assert response["data"].key?("deleted_at")
    
    # Verify deleted timestamp is valid ISO 8601
    deleted_at = response["data"]["deleted_at"]
    assert Time.parse(deleted_at), "Invalid timestamp format: #{deleted_at}"
  end

  # Edge case tests
  def test_delete_message_numeric_id_as_string
    message_id = "123456789"
    
    response = @client.sms.delete_message(message_id: message_id)
    
    assert response
    assert_equal true, response["status"]
    assert_equal message_id, response["data"]["message_id"]
  end

  def test_delete_message_id_with_hyphens_and_underscores
    message_id = "sandbox-message_123-456_789"
    
    response = @client.sms.delete_message(message_id: message_id)
    
    assert response
    assert_equal true, response["status"]
    assert_equal message_id, response["data"]["message_id"]
  end

  def test_delete_message_error_response_structure
    message_id = "sandbox_notfound_structure_test"
    
    error = assert_raises(Cellcast::SMS::APIError) do
      @client.sms.delete_message(message_id: message_id)
    end
    
    # Parse the response body to verify error structure
    response_body = JSON.parse(error.response_body)
    
    # Verify all expected error fields are present
    expected_fields = %w[
      app_type app_version maintainence new_version force_update
      invalid_token refresh_token show_message is_enc status
      message message_type data error
    ]
    
    expected_fields.each do |field|
      assert response_body.key?(field), "Error response missing field: #{field}"
    end
    
    assert_equal false, response_body["status"]
    assert response_body["error"].key?("errorMessage")
  end
end