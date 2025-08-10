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
      { method: :post, path: "send-sms", body: { sms_text: "test", numbers: ["+15550000000"] } },
      { method: :post, path: "bulk-send-sms", body: { sms_text: "test", numbers: ["+15550000000", "+15550000001"] } },
      { method: :get, path: "get-sms", query: "message_id=test123" },
      { method: :get, path: "get-responses", query: "page=1&type=sms" },
      { method: :post, path: "send-sms-nz", body: { sms_text: "test", numbers: ["+6421234567"] } },
      { method: :post, path: "send-sms-template", body: { template_id: "123", numbers: [{ number: "+15550000000", fname: "John" }] } },
      { method: :post, path: "inbound-read", body: { message_id: "test123" } },
      { method: :post, path: "inbound-read-bulk", body: {} },
      { method: :post, path: "register-alpha-id", body: { alpha_id: "TEST", purpose: "Marketing" } },
      { method: :get, path: "account" },
      { method: :get, path: "get-template" },
      { method: :get, path: "get-optout" }
    ]

    valid_tests.each do |test|
      result = @sandbox_handler.handle_request(
        method: test[:method], 
        path: test[:path], 
        body: test[:body],
        query: test[:query]
      )
      
      assert result, "Valid endpoint #{test[:method].upcase} #{test[:path]} should work"
      assert result.is_a?(Hash), "Result should be a hash"
      assert result["meta"], "Response should have meta structure"
    end
  end

  def test_invalid_endpoints_are_rejected
    # Test invalid endpoints that should be rejected (including old API v1 endpoints)
    invalid_tests = [
      { method: :get, path: "nonexistent/endpoint" },
      { method: :post, path: "sms/invalid" },
      { method: :get, path: "api/v2/wrong/path" },
      { method: :delete, path: "sms/wrong/delete/path" },
      { method: :put, path: "completely/wrong" },
      { method: :get, path: "api/wrong/version" },
      # Old API v1 endpoints that no longer exist
      { method: :post, path: "api/v1/gateway" },
      { method: :delete, path: "api/v1/gateway/messages/test123" },
      { method: :get, path: "api/v1/user/token/verify" },
      { method: :post, path: "api/v1/business/add" },
      { method: :post, path: "api/v1/customNumber/add" },
      { method: :get, path: "api/v1/apiClient/account" },
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

  def test_get_message_endpoint_consistency
    # Verify the get message endpoint uses correct path
    message_id = "test_message_123"
    
    # This should work (current implementation)
    response = @sandbox_handler.handle_request(
      method: :get,
      path: "get-sms",
      query: "message_id=#{message_id}"
    )
    
    assert response["meta"], "Get message endpoint should return meta structure"
    assert_equal "SUCCESS", response["meta"]["status"]
    
    # These should fail (wrong paths that don't match any endpoint)
    wrong_paths = [
      "sms/get/#{message_id}",
      "get/#{message_id}",
      "api/v1/gateway/messages/#{message_id}"
    ]
    
    wrong_paths.each do |wrong_path|
      assert_raises(Cellcast::SMS::APIError) do
        @sandbox_handler.handle_request(
          method: :get,
          path: wrong_path,
          body: nil
        )
      end
    end
  end

  def test_method_validation_for_get_message_endpoint
    # Test that non-GET methods on get message endpoint are handled correctly
    message_id = "test_message_123"
    path = "get-sms"
    
    wrong_methods = [:post, :put, :delete, :patch]
    
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