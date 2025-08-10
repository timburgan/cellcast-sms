# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "cellcast"
require "minitest/autorun"
require "minitest/pride"

class TestAPIStructureCompliance < Minitest::Test
  def setup
    @config = Cellcast::SMS::Configuration.new
    @config.sandbox_mode = true
    @config.response_format = :raw  # Use raw responses for API structure testing
    @client = Cellcast.sms(api_key: "test-key", config: @config)
  end

  def test_get_message_request_structure
    # Test that the get message method sends the correct request
    
    # Mock the client's request method to capture what's being sent
    request_captured = nil
    @client.define_singleton_method(:request) do |**args|
      request_captured = args
      # Return a mock response
      {
        "meta" => { "app_type" => "web", "app_version" => "1.0" },
        "msg" => "Message retrieved successfully",
        "data" => {
          "message_id" => "test_message_123",
          "status" => "delivered",
          "to" => "+61400000000",
          "message" => "Test message"
        }
      }
    end
    
    message_id = "test_message_123"
    @client.sms.get_message(message_id: message_id)
    
    # Verify the request structure
    assert_equal :get, request_captured[:method]
    assert_equal "get-sms?message_id=#{message_id}", request_captured[:path]
    assert_nil request_captured[:body] # GET should not have a body
  end

  def test_get_message_response_structure_compliance
    # Test that response structure matches API specification
    message_id = "sandbox_message_123"
    response = @client.sms.get_message(message_id: message_id)
    
    # Test response structure matches documented format
    assert_instance_of Hash, response
    
    # Required top-level fields from official Cellcast API
    required_fields = %w[meta msg data]
    required_fields.each do |field|
      assert response.key?(field), "Response missing required field: #{field}"
    end
    
    # Verify meta structure
    meta = response["meta"]
    assert_instance_of Hash, meta
    assert meta.key?("code"), "Meta missing code field"
    assert meta.key?("status"), "Meta missing status field"
    assert_equal 200, meta["code"]
    assert_equal "SUCCESS", meta["status"]
    
    # Verify message field
    assert_equal "Record found", response["msg"]
    
    # Verify data structure contains message information
    data = response["data"]
    assert_instance_of Array, data
    assert data.length > 0, "Data array should not be empty for successful response"
    
    message_data = data.first
    assert_equal message_id, message_data["message_id"]
    assert message_data.key?("status"), "Message data missing status field"
  end

  def test_error_response_structure_compliance
    # Test error handling for get_message with invalid message IDs
    test_cases = [
      { id: "sandbox_notfound_123", expected_message: "not found" },
      { id: "sandbox_fail_123", expected_message: "fail" }
    ]
    
    test_cases.each do |test_case|
      # In sandbox mode, these should return proper error structures
      response = @client.sms.get_message(message_id: test_case[:id])
      
      # Verify response structure has official meta/msg/data format
      assert response.key?("meta"), "Response missing meta field"
      assert response.key?("msg"), "Response missing msg field"
      
      # For error cases in sandbox, check appropriate response
      assert_includes response["msg"].downcase, test_case[:expected_message]
    end
  end

  def test_convenience_method_response_wrapping
    # Test that convenience method properly returns enhanced response
    message_id = "sandbox_message_456"
    response = @client.get_message_status(message_id: message_id)
    
    # Should return enhanced response object when enhanced mode is enabled
    assert_instance_of Hash, response
    
    # Should have proper API response structure
    assert response.key?("meta"), "Response missing meta field"
    assert response.key?("msg"), "Response missing msg field"
    assert response.key?("data"), "Response missing data field"
  end

  def test_message_id_validation
    # Test input validation for message IDs
    invalid_ids = [nil, "", "   ", "\t\n"]
    
    invalid_ids.each do |invalid_id|
      error = assert_raises(Cellcast::SMS::ValidationError) do
        @client.sms.get_message(message_id: invalid_id)
      end
      
      assert_includes error.message, "Message ID cannot be nil or empty"
    end
  end

  def test_special_sandbox_message_ids
    # Test that special sandbox message IDs work as documented for get_message
    special_ids = {
      "sandbox_message_123" => { success: true },
      "sandbox_notfound_123" => { success: false, message_includes: "not found" },
      "sandbox_fail_123" => { success: false, message_includes: "fail" }
    }
    
    special_ids.each do |message_id, expected|
      response = @client.sms.get_message(message_id: message_id)
      
      # All sandbox responses should have proper structure
      assert response.key?("meta"), "Response missing meta field"
      assert response.key?("msg"), "Response missing msg field"
      
      if expected[:success]
        # Successful responses should have data
        assert response.key?("data"), "Successful response missing data field"
        assert_equal "SUCCESS", response["meta"]["status"]
      else
        # Error responses should indicate the error in the message
        assert_includes response["msg"].downcase, expected[:message_includes]
        assert_equal "ERROR", response["meta"]["status"]
      end
    end
  end

  def test_response_consistency_across_methods
    # Test that responses are consistent between direct SMS API and convenience method
    message_id = "sandbox_message_consistency_test"
    
    # Call via direct SMS API
    direct_response = @client.sms.get_message(message_id: message_id)
    
    # Call via convenience method (should call the same underlying API)
    convenience_response = @client.get_message_status(message_id: message_id)
    
    # Both should have the same essential structure
    assert_equal direct_response["meta"], convenience_response["meta"]
    assert_equal direct_response["msg"], convenience_response["msg"]
    assert_equal direct_response["data"], convenience_response["data"]
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
      response = @client.sms.get_message(message_id: message_id)
      # Should get a valid response structure
      assert response.key?("meta"), "Response missing meta field"
      assert response.key?("msg"), "Response missing msg field"
    end
  end
end