# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "cellcast"
require "minitest/autorun"
require "minitest/pride"

class TestSandboxEndpointValidation < Minitest::Test
  def setup
    @config = Cellcast::SMS::Configuration.new
    @config.sandbox_mode = true
    @client = Cellcast.sms(api_key: "test-key", config: @config)
    @sandbox_handler = Cellcast::SMS::SandboxHandler.new
  end

  def test_valid_endpoints_work
    # Test all officially documented endpoints only
    valid_tests = [
      { method: :post, path: "api/v1/gateway", body: { to: "+15550000000", message: "test" } },
      { method: :post, path: "api/v1/gateway", body: { messages: [{ to: "+15550000000", message: "test" }] } }, # Bulk via same endpoint
      { method: :delete, path: "api/v1/gateway/messages/test123" },
      { method: :get, path: "api/v1/user/token/verify" },
      { method: :post, path: "api/v1/business/add", body: { business_name: "Test", business_registration: "123", contact_info: { email: "test@example.com", phone: "+1234567890" } } },
      { method: :post, path: "api/v1/customNumber/add", body: { phone_number: "+1234567890", purpose: "Support" } },
      { method: :post, path: "api/v1/customNumber/verifyCustomNumber", body: { phone_number: "+1234567890", verification_code: "123456" } },
      { method: :get, path: "api/v1/apiClient/account" },
      { method: :get, path: "api/v2/report/message/quick-api-credit-usage" }
    ]

    valid_tests.each do |test|
      result = @sandbox_handler.handle_request(
        method: test[:method], 
        path: test[:path], 
        body: test[:body]
      )
      
      assert result, "Valid endpoint #{test[:method].upcase} #{test[:path]} should work"
      assert result.is_a?(Hash), "Result should be a hash"
    end
  end

  def test_invalid_endpoints_are_rejected
    # Test invalid endpoints that should be rejected (including previously supported but undocumented ones)
    invalid_tests = [
      { method: :get, path: "nonexistent/endpoint" },
      { method: :post, path: "sms/invalid" },
      { method: :get, path: "api/v2/wrong/path" },
      { method: :delete, path: "sms/wrong/delete/path" },
      { method: :put, path: "completely/wrong" },
      { method: :get, path: "api/wrong/version" },
      # Previously supported but undocumented endpoints
      { method: :post, path: "api/v1/gateway/bulk" },
      { method: :get, path: "api/v1/gateway/status/test123" },
      { method: :get, path: "api/v1/gateway/delivery/test123" },
      { method: :get, path: "api/v1/gateway/messages" },
      { method: :get, path: "api/v1/incoming" },
      { method: :post, path: "api/v1/incoming/mark-read" },
      { method: :get, path: "api/v1/incoming/replies/test123" },
      { method: :post, path: "api/v1/webhooks/configure" },
      { method: :get, path: "api/v1/sender-id/business-name" }
    ]

    invalid_tests.each do |test|
      error = assert_raises(Cellcast::SMS::APIError) do
        @sandbox_handler.handle_request(
          method: test[:method], 
          path: test[:path], 
          body: nil
        )
      end
      
      assert_equal 404, error.status_code, "Invalid endpoint should return 404"
      assert_includes error.message, "Endpoint not found", "Error should mention endpoint not found"
      assert_includes error.message, test[:path], "Error should include the invalid path"
      
      # Verify response body structure
      response_body = JSON.parse(error.response_body)
      assert_equal false, response_body["status"]
      assert_equal "Endpoint not found", response_body["message"]
      assert response_body["error"]["errorMessage"].include?(test[:path])
    end
  end

  def test_delete_message_endpoint_consistency
    # Verify the delete message endpoint uses correct path
    message_id = "test_message_123"
    
    # This should work (current implementation)
    response = @sandbox_handler.handle_request(
      method: :delete,
      path: "api/v1/gateway/messages/#{message_id}",
      body: nil
    )
    
    assert response["status"], "Delete message endpoint should work"
    assert_equal message_id, response["data"]["message_id"]
    
    # These should fail (wrong paths that don't match any endpoint)
    wrong_paths = [
      "sms/delete/#{message_id}",
      "delete/#{message_id}",
      "api/v2/gateway/messages/#{message_id}"
    ]
    
    wrong_paths.each do |wrong_path|
      assert_raises(Cellcast::SMS::APIError) do
        @sandbox_handler.handle_request(
          method: :delete,
          path: wrong_path,
          body: nil
        )
      end
    end
    
    # Note: sms/messages/test123 matches the list messages endpoint,
    # which is correct behavior for the API
  end

  def test_method_validation_for_delete_endpoint
    # Test that non-DELETE methods on delete endpoint are handled correctly
    message_id = "test_message_123"
    path = "api/v1/gateway/messages/#{message_id}"
    
    wrong_methods = [:get, :post, :put, :patch]
    
    wrong_methods.each do |method|
      # The delete handler should return success for non-DELETE methods
      # (based on current implementation that calls handle_generic_success)
      response = @sandbox_handler.handle_request(
        method: method,
        path: path,
        body: nil
      )
      
      # This should return generic success rather than delete-specific response
      assert response["success"], "Non-DELETE method should return generic success"
      refute response.key?("data"), "Non-DELETE method should not return delete-specific data"
    end
  end

  def test_client_level_endpoint_validation
    # Test that invalid endpoints fail at the client level too
    assert_raises(Cellcast::SMS::APIError) do
      @client.send(:request, method: :get, path: "invalid/endpoint")
    end
  end

  def test_error_response_structure_consistency
    # Verify all error responses have consistent structure
    error = assert_raises(Cellcast::SMS::APIError) do
      @sandbox_handler.handle_request(method: :get, path: "invalid/path", body: nil)
    end
    
    response_body = JSON.parse(error.response_body)
    
    # Verify all required fields are present
    required_fields = %w[
      app_type app_version maintainence new_version force_update
      invalid_token refresh_token show_message is_enc status
      message message_type data error
    ]
    
    required_fields.each do |field|
      assert response_body.key?(field), "Response should include field: #{field}"
    end
    
    # Verify error structure
    assert response_body["error"].key?("errorMessage")
    assert_equal false, response_body["status"]
    assert_equal 1, response_body["show_message"]
  end
end