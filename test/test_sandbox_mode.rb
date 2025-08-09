# frozen_string_literal: true

require "test_helper"

class TestSandboxMode < Minitest::Test
  def setup
    @config = Cellcast::SMS::Configuration.new
    @config.sandbox_mode = true
    @client = Cellcast.sms(api_key: "test_api_key", config: @config)
  end

  def test_sandbox_mode_enabled_in_config
    assert @config.sandbox_mode
    refute Cellcast::SMS::Configuration.new.sandbox_mode # Default is false
  end

  def test_sandbox_success_number
    response = @client.quick_send(to: "+15550000000", message: "Test", from: "TEST")
    assert response.success?
    assert_equal "queued", response.status
    refute_nil response.message_id
    assert response.message_id.start_with?("sandbox_")
    assert_equal 0.05, response.cost
  end

  def test_sandbox_failed_number
    response = @client.quick_send(to: "+15550000001", message: "Test", from: "TEST")
    refute response.success?
    assert_equal "failed", response.status
    assert_equal "Sandbox test failure", response.raw_response["failed_reason"]
  end

  def test_sandbox_rate_limit_number
    assert_raises(Cellcast::SMS::RateLimitError) do
      @client.quick_send(to: "+15550000002", message: "Test", from: "TEST")
    end
  end

  def test_sandbox_invalid_number
    assert_raises(Cellcast::SMS::ValidationError) do
      @client.quick_send(to: "+15550000003", message: "Test", from: "TEST")
    end
  end

  def test_sandbox_insufficient_credits_number
    assert_raises(Cellcast::SMS::APIError) do
      @client.quick_send(to: "+15550000004", message: "Test", from: "TEST")
    end
  end

  def test_sandbox_broadcast
    response = @client.broadcast(
      to: ["+15550000000", "+15550000001", "+15551234567"],
      message: "Test broadcast",
      from: "TEST"
    )

    assert_equal 3, response.total_count
    assert_equal 2, response.successful_count
    assert_equal 1, response.failed_count
    assert_equal 0.1, response.total_cost
  end

  def test_sandbox_token_verification
    response = @client.verify_token
    assert response.success?
    assert response.raw_response["data"]["token"]
  end

  def test_sandbox_account_balance
    response = @client.balance
    assert response.success?
    balance_data = response.raw_response["data"]
    assert balance_data["balance"]
    assert balance_data["currency"]
  end

  def test_sandbox_usage_report
    response = @client.usage_report
    assert response.success?
    usage_data = response.raw_response["data"]
    assert usage_data["total_messages"]
    assert usage_data["total_cost"]
  end

  def test_sandbox_register_business
    response = @client.register_business(
      business_name: "Test Business",
      business_registration: "ABN123456789",
      contact_info: { email: "test@example.com", phone: "+1234567890" }
    )
    
    assert response.success?
    business_data = response.raw_response["data"]
    assert_equal "Test Business", business_data["business_name"]
    assert_equal "pending_approval", business_data["status"]
  end

  def test_sandbox_register_number
    response = @client.register_number(
      phone_number: "+1234567890",
      purpose: "Customer support"
    )
    
    assert response.success?
    number_data = response.raw_response["data"]
    assert_equal "+1234567890", number_data["phone_number"]
    assert_equal "pending_verification", number_data["status"]
  end

  def test_sandbox_verify_number
    response = @client.verify_number(
      phone_number: "+1234567890",
      verification_code: "123456"
    )
    
    assert response.success?
    verify_data = response.raw_response["data"]
    assert_equal "+1234567890", verify_data["phone_number"]
    assert_equal "verified", verify_data["status"]
  end

  def test_regular_phone_number_defaults_to_success
    response = @client.quick_send(to: "+15551234567", message: "Test", from: "TEST")
    assert response.success?
    assert_equal "queued", response.status
  end

  def test_sandbox_responses_contain_metadata
    response = @client.sms.send_message(to: "+15550000000", message: "Test")

    # Verify response structure matches real API
    assert response["id"]
    assert response["message_id"]
    assert response["to"]
    assert response["status"]
    assert response["cost"]
    assert response["parts"]
    assert response["created_at"]
  end
end
