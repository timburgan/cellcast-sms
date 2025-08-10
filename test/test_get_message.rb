# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "cellcast"
require "minitest/autorun"
require "minitest/pride"

class TestGetMessage < Minitest::Test
  def setup
    @config = Cellcast::SMS::Configuration.new
    @config.sandbox_mode = true
    @client = Cellcast.sms(api_key: "test-key", config: @config)
  end

  def test_get_message_success
    message_id = "test_message_123"

    response = @client.sms.get_message(message_id: message_id)

    assert response.is_a?(Hash), "Response should be a hash"
    assert_equal "SUCCESS", response.dig("meta", "status")
    assert response["data"].is_a?(Array), "Data should be an array"
    assert response["data"].first["message_id"], "Should include message_id"
  end

  def test_get_message_not_found
    message_id = "nonexistent_message_456"

    # In sandbox mode, this should still return a success response with sample data
    response = @client.sms.get_message(message_id: message_id)
    
    assert response.is_a?(Hash), "Response should be a hash"
    # Sandbox returns success even for nonexistent messages
    assert_equal "SUCCESS", response.dig("meta", "status")
  end

  def test_get_message_validation_empty_id
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.get_message(message_id: "")
    end

    assert_includes error.message, "Message ID cannot be nil or empty"
  end

  def test_get_message_validation_nil_id
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.get_message(message_id: nil)
    end

    assert_includes error.message, "Message ID cannot be nil or empty"
  end

  def test_get_message_validation_whitespace_id
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.get_message(message_id: "   ")
    end

    assert_includes error.message, "Message ID cannot be nil or empty"
  end

  def test_get_message_with_special_characters
    message_id = "test-message_123!@#"

    response = @client.sms.get_message(message_id: message_id)

    assert response.is_a?(Hash), "Response should be a hash"
    assert_equal "SUCCESS", response.dig("meta", "status")
  end

  def test_convenience_get_message_status_success
    message_id = "test_message_789"

    response = @client.get_message_status(message_id: message_id)

    # The convenience method returns an enhanced response object
    assert response.is_a?(Cellcast::SMS::MessageDetailsResponse), "Response should be an enhanced response object"
    assert response.success?, "Response should be successful"
    assert_equal "SUCCESS", response.dig("meta", "status")
  end

  def test_get_message_unicode_id
    message_id = "测试消息_123"

    response = @client.sms.get_message(message_id: message_id)

    assert response.is_a?(Hash), "Response should be a hash"
    assert_equal "SUCCESS", response.dig("meta", "status")
  end

  def test_get_message_very_long_id
    message_id = "a" * 1000

    response = @client.sms.get_message(message_id: message_id)

    assert response.is_a?(Hash), "Response should be a hash"
    assert_equal "SUCCESS", response.dig("meta", "status")
  end

  def test_get_message_response_structure
    message_id = "structure_test_456"

    response = @client.sms.get_message(message_id: message_id)

    # Verify official API response structure
    assert response.key?("meta"), "Response should have meta"
    assert response.key?("msg"), "Response should have msg"
    assert response.key?("data"), "Response should have data"
    
    assert response["meta"].key?("code"), "Meta should have code"
    assert response["meta"].key?("status"), "Meta should have status"
    
    assert response["data"].is_a?(Array), "Data should be an array"
    
    if response["data"].any?
      message = response["data"].first
      assert message.key?("to"), "Message should have to field"
      assert message.key?("body"), "Message should have body field"
      assert message.key?("message_id"), "Message should have message_id field"
      assert message.key?("status"), "Message should have status field"
    end
  end

  def test_get_message_numeric_id_as_string
    message_id = "123456789"

    response = @client.sms.get_message(message_id: message_id)

    assert response.is_a?(Hash), "Response should be a hash"
    assert_equal "SUCCESS", response.dig("meta", "status")
  end

  def test_get_message_id_with_hyphens_and_underscores
    message_id = "msg-123_test-456_final"

    response = @client.sms.get_message(message_id: message_id)

    assert response.is_a?(Hash), "Response should be a hash"
    assert_equal "SUCCESS", response.dig("meta", "status")
  end
end