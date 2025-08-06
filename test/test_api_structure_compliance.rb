# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "cellcast"
require "minitest/autorun"
require "minitest/pride"

class TestAPIStructureCompliance < Minitest::Test
  def setup
    @config = Cellcast::SMS::Configuration.new
    @config.sandbox_mode = true
    @client = Cellcast.sms(api_key: "test-key", config: @config)
  end

  def test_delete_message_request_structure
    # Test that the delete message method sends the correct request
    
    # Mock the client's request method to capture what's being sent
    request_captured = nil
    @client.define_singleton_method(:request) do |**args|
      request_captured = args
      # Return a mock response
      {
        "app_type" => "web",
        "app_version" => "1.0",
        "status" => true,
        "message" => "Message deleted successfully",
        "data" => {
          "message_id" => args[:path].split('/').last,
          "deleted" => true,
          "deleted_at" => Time.now.utc.iso8601
        }
      }
    end
    
    message_id = "test_message_123"
    @client.sms.delete_message(message_id: message_id)
    
    # Verify the request structure
    assert_equal :delete, request_captured[:method]
    assert_equal "api/v1/gateway/messages/#{message_id}", request_captured[:path]
    assert_nil request_captured[:body] # DELETE should not have a body
  end

  def test_delete_message_response_structure_compliance
    # Test that response structure matches API specification
    message_id = "sandbox_message_123"
    response = @client.sms.delete_message(message_id: message_id)
    
    # Test response structure matches documented format
    assert_instance_of Hash, response
    
    # Required top-level fields
    required_fields = %w[app_type app_version status message data]
    required_fields.each do |field|
      assert response.key?(field), "Response missing required field: #{field}"
    end
    
    # Verify field values
    assert_equal "web", response["app_type"]
    assert_equal "1.0", response["app_version"]
    assert_equal true, response["status"]
    assert_equal "Message deleted successfully", response["message"]
    
    # Verify data structure
    data = response["data"]
    assert_instance_of Hash, data
    assert_equal message_id, data["message_id"]
    assert_equal true, data["deleted"]
    assert data.key?("deleted_at")
    
    # Verify timestamp format (ISO 8601)
    deleted_at = data["deleted_at"]
    assert Time.parse(deleted_at), "deleted_at should be valid timestamp"
    assert deleted_at.end_with?("Z"), "deleted_at should be UTC (end with Z)"
  end

  def test_error_response_structure_compliance
    # Test error responses match API specification
    test_cases = [
      { id: "sandbox_notfound_123", expected_status: 404, expected_message: "Message not found" },
      { id: "sandbox_already_sent_123", expected_status: 400, expected_message: "Cannot delete already sent" },
      { id: "sandbox_fail_123", expected_status: 500, expected_message: "Delete operation failed" }
    ]
    
    test_cases.each do |test_case|
      error = assert_raises(Cellcast::SMS::APIError) do
        @client.sms.delete_message(message_id: test_case[:id])
      end
      
      assert_equal test_case[:expected_status], error.status_code
      assert_includes error.message, test_case[:expected_message]
      
      # Parse and validate error response body structure
      response = JSON.parse(error.response_body)
      
      # Required fields for error responses
      error_fields = %w[app_type app_version status message error]
      error_fields.each do |field|
        assert response.key?(field), "Error response missing field: #{field}"
      end
      
      # Verify error-specific fields
      assert_equal false, response["status"]
      assert response["error"].key?("errorMessage")
      assert_instance_of String, response["error"]["errorMessage"]
    end
  end

  def test_convenience_method_response_wrapping
    # Test that convenience method properly wraps response
    message_id = "sandbox_message_456"
    response = @client.cancel_message(message_id: message_id)
    
    # Should return a Response wrapper object
    assert_instance_of Cellcast::SMS::Response, response
    assert response.success?
    
    # Should have access to underlying data
    assert_equal "Message deleted successfully", response["message"]
    assert_equal message_id, response["data"]["message_id"]
  end

  def test_message_id_validation
    # Test input validation for message IDs
    invalid_ids = [nil, "", "   ", "\t\n"]
    
    invalid_ids.each do |invalid_id|
      error = assert_raises(Cellcast::SMS::ValidationError) do
        @client.sms.delete_message(message_id: invalid_id)
      end
      
      assert_includes error.message, "Message ID cannot be nil or empty"
    end
  end

  def test_special_sandbox_message_ids
    # Test that special sandbox message IDs work as documented
    special_ids = {
      "sandbox_message_123" => { success: true, status: true },
      "sandbox_notfound_123" => { success: false, error_status: 404 },
      "sandbox_already_sent_123" => { success: false, error_status: 400 },
      "sandbox_fail_123" => { success: false, error_status: 500 }
    }
    
    special_ids.each do |message_id, expected|
      if expected[:success]
        response = @client.sms.delete_message(message_id: message_id)
        assert_equal expected[:status], response["status"]
        assert_equal message_id, response["data"]["message_id"]
      else
        error = assert_raises(Cellcast::SMS::APIError) do
          @client.sms.delete_message(message_id: message_id)
        end
        assert_equal expected[:error_status], error.status_code
      end
    end
  end

  def test_response_consistency_across_methods
    # Test that responses are consistent between direct SMS API and convenience method
    message_id = "sandbox_message_consistency_test"
    
    # Call via direct SMS API
    direct_response = @client.sms.delete_message(message_id: message_id)
    
    # Call via convenience method (should call the same underlying API)
    convenience_response = @client.cancel_message(message_id: message_id)
    
    # Both should have the same essential structure
    assert_equal direct_response["status"], convenience_response["status"]
    assert_equal direct_response["message"], convenience_response["message"]
    assert_equal direct_response["data"]["message_id"], convenience_response["data"]["message_id"]
  end

  def test_unicode_and_special_characters_in_message_ids
    # Test that message IDs with unicode and special characters work
    special_message_ids = [
      "sandbox_message_with-hyphens",
      "sandbox_message_with_underscores",
      "sandbox_123_456_789",
      "sandbox_message_测试", # Unicode characters
      "sandbox_message_with.dots"
    ]
    
    special_message_ids.each do |message_id|
      response = @client.sms.delete_message(message_id: message_id)
      assert_equal true, response["status"]
      assert_equal message_id, response["data"]["message_id"]
    end
  end
end