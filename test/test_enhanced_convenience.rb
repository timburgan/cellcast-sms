# frozen_string_literal: true

require "test_helper"

class TestEnhancedConvenience < Minitest::Test
  def setup
    config = Cellcast::SMS::Configuration.new
    config.sandbox_mode = true
    config.response_format = :enhanced  # Test enhanced responses
    config.default_sender_id = "TestBrand"
    config.chunk_size = 50
    @client = Cellcast.sms(api_key: "test_key", config: config)
  end

  def test_enhanced_quick_send
    response = @client.quick_send(
      to: "+1234567890",
      message: "Hello world"
    )

    assert_instance_of Cellcast::SMS::SendSmsResponse, response
    assert response.success?
    refute response.error?
    assert_equal "SUCCESS", response.dig("meta", "status")
    assert response.message_id, "Should have message_id"
    assert_equal "Queued", response.api_message
    assert_equal 1, response.total_numbers
    assert_equal 1, response.success_number
    assert_equal 1, response.credits_used
    assert response.all_successful?
    assert_equal "+1234567890", response.to
    assert_equal "TestBrand", response.from  # Should use default sender ID
  end

  def test_enhanced_quick_send_with_custom_sender
    response = @client.quick_send(
      to: "+1234567890",
      message: "Hello world",
      from: "CustomSender"
    )

    assert_instance_of Cellcast::SMS::SendSmsResponse, response
    assert response.success?
    assert_equal "CustomSender", response.from
  end

  def test_enhanced_quick_send_failure
    response = @client.quick_send(
      to: "+15550000001",  # Special test number that fails
      message: "Test failure"
    )

    assert_instance_of Cellcast::SMS::SendSmsResponse, response
    refute response.success?
    assert response.error?
    assert_equal "FAILED", response.dig("meta", "status")
    assert_equal "Message failed to send", response.api_message
    refute response.all_successful?
  end

  def test_enhanced_broadcast_single_recipient
    response = @client.broadcast(
      to: ["+1234567890"],
      message: "Single recipient broadcast"
    )

    # Should optimize to quick_send for single recipient
    assert_instance_of Cellcast::SMS::SendSmsResponse, response
    assert response.success?
    assert_equal 1, response.total_numbers
  end

  def test_enhanced_broadcast_multiple_recipients
    response = @client.broadcast(
      to: ["+1234567890", "+1987654321"],
      message: "Broadcast message"
    )

    assert_instance_of Cellcast::SMS::BulkSmsResponse, response
    assert response.success?
    assert_equal 2, response.total_numbers
    assert_equal 2, response.success_number
    assert_equal 0, response.failed_number
    assert response.all_successful?
    refute response.has_failures?
    assert_equal 100.0, response.success_rate
    assert_equal 2, response.messages.length
  end

  def test_enhanced_broadcast_mixed_results
    response = @client.broadcast(
      to: ["+15550000000", "+15550000001"], # Success + failed
      message: "Mixed results broadcast"
    )

    assert_instance_of Cellcast::SMS::BulkSmsResponse, response
    assert response.success?  # API call succeeds even with some failures
    assert_equal 2, response.total_numbers
    assert_equal 1, response.success_number
    assert_equal 1, response.failed_number
    refute response.all_successful?
    assert response.has_failures?
    assert_equal 50.0, response.success_rate
  end

  def test_chainable_operations_success
    result = nil
    error_called = false

    response = @client.quick_send(
      to: "+1234567890",
      message: "Chainable test"
    ).on_success { |r| result = r.message_id }
     .on_error { |r| error_called = true }

    assert_instance_of Cellcast::SMS::SendSmsResponse, response
    assert result, "Success handler should have been called"
    refute error_called, "Error handler should not have been called"
  end

  def test_chainable_operations_error
    result = nil
    error_result = nil

    response = @client.quick_send(
      to: "+15550000001",  # Fails
      message: "Chainable error test"
    ).on_success { |r| result = r.message_id }
     .on_error { |r| error_result = r.api_message }

    assert_instance_of Cellcast::SMS::SendSmsResponse, response
    assert_nil result, "Success handler should not have been called"
    assert_equal "Message failed to send", error_result
  end

  def test_enhanced_get_message_status
    response = @client.get_message_status(message_id: "test_message_123")

    assert_instance_of Cellcast::SMS::MessageDetailsResponse, response
    assert response.success?
    assert response.message_id
    assert response.to
    assert response.message_text
    assert response.status
  end

  def test_enhanced_get_inbound_messages
    response = @client.get_inbound_messages(page: 1)

    assert_instance_of Cellcast::SMS::InboundMessagesResponse, response
    assert response.success?
    assert_respond_to response, :messages
    assert_respond_to response, :each_message
    assert_respond_to response, :current_page
    assert_respond_to response, :total_pages
    assert_respond_to response, :has_more_pages?
    assert_equal 1, response.current_page
    assert response.first_page?
  end

  def test_enhanced_balance
    response = @client.balance

    assert_instance_of Cellcast::SMS::AccountBalanceResponse, response
    assert response.success?
    assert response.sms_balance
    assert response.mms_balance
    assert response.account_name
    
    # Test balance checking methods
    refute response.low_sms_balance?(10)  # Should have enough balance
    refute response.low_mms_balance?(5)
    refute response.low_balance?
    assert response.total_balance > 0
  end

  def test_enhanced_templates
    response = @client.get_templates

    assert_instance_of Cellcast::SMS::TemplatesResponse, response
    assert response.success?
    assert_respond_to response, :templates
    assert_respond_to response, :template_count
    assert_respond_to response, :find_template
    assert_respond_to response, :has_templates?
  end

  def test_enhanced_register_alpha_id
    response = @client.register_alpha_id(
      alpha_id: "TEST",
      purpose: "Marketing notifications"
    )

    assert_instance_of Cellcast::SMS::RegistrationResponse, response
    assert response.success?
    assert_respond_to response, :registration_id
    assert_respond_to response, :registration_status
  end

  def test_low_balance_detection
    # This tests the convenience method for checking low balance
    refute @client.low_balance?, "Should not have low balance with default thresholds"
    assert @client.low_balance?(sms_threshold: 200), "Should have low balance with high threshold (125.50 < 200)"
  end

  def test_find_template_functionality
    # Mock a template in the response (would need to adjust sandbox for real testing)
    template = @client.find_template("nonexistent")
    assert_nil template, "Should return nil for non-existent template"
  end

  def test_send_to_nz_enhanced
    response = @client.send_to_nz(
      to: "+64211234567",
      message: "Hello New Zealand!"
    )

    assert_instance_of Cellcast::SMS::SendSmsResponse, response
    assert response.success?
    assert_equal "+64211234567", response.to
    assert_equal "TestBrand", response.from  # Should use default sender
  end

  def test_response_preserves_hash_interface
    response = @client.quick_send(
      to: "+1234567890",
      message: "Hash interface test"
    )

    # Should still work like a hash for backward compatibility
    assert_equal "SUCCESS", response["meta"]["status"]
    assert_equal "Queued", response["msg"]
    assert response.dig("data", "messages", 0, "message_id")
    
    # Should support enumeration
    assert_respond_to response, :each
    assert_respond_to response, :to_h
    assert response.to_h.is_a?(Hash)
  end

  def test_bulk_response_collection_for_large_broadcast
    # This tests chunking with more recipients than chunk size
    recipients = (1..60).map { |i| "+123456789#{i.to_s.rjust(2, '0')}" }
    
    response = @client.broadcast(
      to: recipients,
      message: "Large broadcast test"
    )

    # With 60 recipients and chunk size 50, should get BulkResponseCollection
    assert_instance_of Cellcast::SMS::BulkResponseCollection, response
    assert response.success?, "Broadcast should succeed in sandbox mode"
    assert_equal 60, response.total_numbers
  end

  def test_string_representations
    response = @client.quick_send(
      to: "+1234567890",
      message: "String test"
    )

    string_repr = response.to_s
    assert_includes string_repr, "SendSmsResponse"
    assert_includes string_repr, "success: true"
    assert_includes string_repr, "Queued"
  end
end