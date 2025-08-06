# frozen_string_literal: true

require "test_helper"

class TestSandboxComprehensive < Minitest::Test
  def setup
    @config = Cellcast::SMS::Configuration.new
    @config.sandbox_mode = true
    @client = Cellcast.sms(api_key: "test_api_key", config: @config)
  end

  # Test sandbox mode is opt-in only (disabled by default)
  def test_sandbox_mode_is_opt_in_only
    default_config = Cellcast::SMS::Configuration.new
    refute default_config.sandbox_mode, "Sandbox mode should be disabled by default"

    # Explicitly enabling should work
    default_config.sandbox_mode = true
    assert default_config.sandbox_mode, "Should be able to enable sandbox mode"

    # Should default to false again
    another_config = Cellcast::SMS::Configuration.new
    refute another_config.sandbox_mode, "New configuration should default to disabled"
  end

  # Test boundary conditions for phone numbers
  def test_sandbox_phone_number_edge_cases
    # Empty phone number should still trigger validation
    assert_raises(Cellcast::SMS::ValidationError) do
      @client.quick_send(to: "", message: "Test", from: "TEST")
    end

    # Nil phone number should trigger validation
    assert_raises(Cellcast::SMS::ValidationError) do
      @client.quick_send(to: nil, message: "Test", from: "TEST")
    end

    # Non-string phone number
    assert_raises(Cellcast::SMS::ValidationError) do
      @client.quick_send(to: 1_234_567_890, message: "Test", from: "TEST")
    end

    # Test number variations (different formats but same special number)
    response = @client.quick_send(to: "+15550000000", message: "Test", from: "TEST")
    assert response.success?

    # Leading/trailing whitespace in test numbers
    response = @client.quick_send(to: " +15550000000 ", message: "Test", from: "TEST")
    assert response.success?
  end

  # Test message content edge cases
  def test_sandbox_message_edge_cases
    # Empty message should trigger validation
    assert_raises(Cellcast::SMS::ValidationError) do
      @client.quick_send(to: "+15550000000", message: "", from: "TEST")
    end

    # Nil message should trigger validation
    assert_raises(Cellcast::SMS::ValidationError) do
      @client.quick_send(to: "+15550000000", message: nil, from: "TEST")
    end

    # Very long message (over limit)
    long_message = "a" * 1601 # Assuming 1600 char limit
    assert_raises(Cellcast::SMS::ValidationError) do
      @client.quick_send(to: "+15550000000", message: long_message, from: "TEST")
    end

    # Message exactly at limit should work
    limit_message = "a" * 1600
    response = @client.quick_send(to: "+15550000000", message: limit_message, from: "TEST")
    assert response.success?

    # Unicode message
    unicode_message = "Hello 🌍 こんにちは 🚀"
    response = @client.quick_send(to: "+15550000000", message: unicode_message, from: "TEST")
    assert response.success?
  end

  # Test bulk operations edge cases
  def test_sandbox_bulk_edge_cases
    # Empty array
    assert_raises(Cellcast::SMS::ValidationError) do
      @client.broadcast(to: [], message: "Test", from: "TEST")
    end

    # Single recipient (minimum)
    response = @client.broadcast(to: ["+15550000000"], message: "Test", from: "TEST")
    assert_equal 1, response.total_count
    assert_equal 1, response.successful_count

    # Mix of success and failure numbers
    recipients = [
      "+15550000000",  # Success
      "+15550000001",  # Failure
      "+15551234567", # Success (default)
    ]
    response = @client.broadcast(to: recipients, message: "Test", from: "TEST")
    assert_equal 3, response.total_count
    assert_equal 2, response.successful_count
    assert_equal 1, response.failed_count

    # All failures
    response = @client.broadcast(to: ["+15550000001", "+15550000001"], message: "Test", from: "TEST")
    assert_equal 2, response.total_count
    assert_equal 0, response.successful_count
    assert_equal 2, response.failed_count
  end

  # Test API key edge cases in sandbox mode
  def test_sandbox_api_key_edge_cases
    # Empty API key should still trigger validation
    assert_raises(Cellcast::SMS::ValidationError) do
      Cellcast.sms(api_key: "", config: @config)
    end

    # Nil API key should trigger validation
    assert_raises(Cellcast::SMS::ValidationError) do
      Cellcast.sms(api_key: nil, config: @config)
    end

    # Whitespace-only API key should trigger validation
    assert_raises(Cellcast::SMS::ValidationError) do
      Cellcast.sms(api_key: "   ", config: @config)
    end

    # Any non-empty API key should work in sandbox mode
    client = Cellcast.sms(api_key: "invalid-but-non-empty", config: @config)
    response = client.quick_send(to: "+15550000000", message: "Test", from: "TEST")
    assert response.success?
  end

  # Test special numbers exhaustively
  def test_all_special_numbers_thoroughly
    # Test success number multiple times
    5.times do
      response = @client.quick_send(to: "+15550000000", message: "Test", from: "TEST")
      assert response.success?
      assert_equal "queued", response.status
      assert_equal 0.05, response.cost
      assert_equal 1, response.parts
      assert response.message_id.start_with?("sandbox_")
      refute_nil response.raw_response["created_at"]
    end

    # Test failure number multiple times
    5.times do
      response = @client.quick_send(to: "+15550000001", message: "Test", from: "TEST")
      refute response.success?
      assert_equal "failed", response.status
      assert_equal 0.0, response.cost
      assert_equal "Sandbox test failure", response.raw_response["failed_reason"]
    end

    # Test rate limit number multiple times
    5.times do
      error = assert_raises(Cellcast::SMS::RateLimitError) do
        @client.quick_send(to: "+15550000002", message: "Test", from: "TEST")
      end
      assert_equal 429, error.status_code
      assert_equal 60, error.retry_after
      assert_includes error.message, "Rate limit exceeded"
    end

    # Test invalid number multiple times
    5.times do
      error = assert_raises(Cellcast::SMS::ValidationError) do
        @client.quick_send(to: "+15550000003", message: "Test", from: "TEST")
      end
      assert_includes error.message, "Invalid phone number format"
      assert_includes error.message, "+15550000003"
    end

    # Test insufficient credits multiple times
    5.times do
      error = assert_raises(Cellcast::SMS::APIError) do
        @client.quick_send(to: "+15550000004", message: "Test", from: "TEST")
      end
      assert_equal 422, error.status_code # Updated to match official API docs
      assert_includes error.message, "Insufficient credits"
    end
  end

  # Test all API endpoints work in sandbox mode
  def test_all_endpoints_in_sandbox
    # SMS API endpoints
    response = @client.sms.send_message(to: "+15550000000", message: "Test")
    assert response["id"]
    assert response["status"]

    bulk_response = @client.sms.send_bulk(messages: [{ to: "+15550000000", message: "Test" }])
    # Check for official API structure
    assert bulk_response["data"]
    assert bulk_response["data"]["queueResponse"]

    status_response = @client.sms.get_status(message_id: "test_msg")
    assert status_response["status"]

    delivery_response = @client.sms.get_delivery_report(message_id: "test_msg")
    assert delivery_response["delivery_report"]

    list_response = @client.sms.list_messages(limit: 10)
    assert list_response["data"]

    # Incoming API endpoints
    incoming_response = @client.incoming.list_incoming(limit: 10)
    assert incoming_response["data"]

    mark_read_response = @client.incoming.mark_as_read(message_ids: %w[msg1 msg2])
    assert mark_read_response["marked_read"]

    replies_response = @client.incoming.get_replies(original_message_id: "test_msg")
    assert replies_response["data"]

    # Webhook API endpoints
    webhook_response = @client.webhook.configure_webhook(
      url: "https://example.com/webhook",
      events: ["sms.delivered"]
    )
    assert webhook_response["webhook_id"]

    test_webhook_response = @client.webhook.test_webhook
    assert test_webhook_response["test_sent"]

    # Sender ID API endpoints
    sender_id_response = @client.sender_id.list_sender_ids
    assert sender_id_response["data"]["sender_ids"] # Updated to match official API structure

    # Token API endpoints
    token_response = @client.token.verify_token
    assert token_response["status"] # Updated to match official API structure
  end

  # Test sandbox responses are realistic
  def test_sandbox_responses_realistic_structure
    response = @client.quick_send(to: "+15550000000", message: "Test", from: "TEST")

    # Check all expected fields are present
    assert response.raw_response["id"]
    assert response.raw_response["message_id"]
    assert response.raw_response["to"]
    assert response.raw_response["status"]
    assert response.raw_response["cost"].is_a?(Numeric)
    assert response.raw_response["parts"].is_a?(Integer)
    assert response.raw_response["created_at"]

    # Check format of timestamps
    assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, response.raw_response["created_at"])

    # Check message ID format
    assert_match(/^sandbox_\d+_\d+$/, response.raw_response["message_id"])

    # Check phone number preservation
    assert_equal "+15550000000", response.raw_response["to"]
  end

  # Test sandbox mode isolation
  def test_sandbox_mode_isolation
    # Sandbox client should not affect regular client
    regular_config = Cellcast::SMS::Configuration.new
    refute regular_config.sandbox_mode

    # Create both types of clients
    Cellcast.sms(api_key: "test", config: @config)
    Cellcast.sms(api_key: "test", config: regular_config)

    # Verify sandbox client is in sandbox mode
    assert @config.sandbox_mode

    # Verify regular client is not in sandbox mode
    refute regular_config.sandbox_mode

    # They should be independent
    @config.sandbox_mode = false
    refute @config.sandbox_mode
    refute regular_config.sandbox_mode # Should remain unchanged
  end

  # Test concurrent sandbox usage
  def test_concurrent_sandbox_usage
    # Create multiple sandbox clients
    clients = 5.times.map do
      config = Cellcast::SMS::Configuration.new
      config.sandbox_mode = true
      Cellcast.sms(api_key: "test_#{rand(1000)}", config: config)
    end

    # All should work independently
    responses = clients.map do |client|
      client.quick_send(to: "+15550000000", message: "Test", from: "TEST")
    end

    # All should succeed
    responses.each do |response|
      assert response.success?
      assert response.message_id.start_with?("sandbox_")
    end

    # Each should have unique message IDs
    message_ids = responses.map(&:message_id)
    assert_equal message_ids.uniq.length, message_ids.length, "Message IDs should be unique"
  end

  # Test sandbox mode with malformed inputs
  def test_sandbox_malformed_inputs
    # Test with hash instead of string for phone number
    assert_raises(Cellcast::SMS::ValidationError) do
      @client.quick_send(to: { phone: "+15550000000" }, message: "Test", from: "TEST")
    end

    # Test with array instead of string for message
    assert_raises(Cellcast::SMS::ValidationError) do
      @client.quick_send(to: "+15550000000", message: %w[Test Message], from: "TEST")
    end

    # Test with very large numbers
    huge_number = "+#{'9' * 50}"
    assert_raises(Cellcast::SMS::ValidationError) do
      @client.quick_send(to: huge_number, message: "Test", from: "TEST")
    end
  end

  # Test sandbox logging if logger is configured
  def test_sandbox_logging
    require "logger"
    require "stringio"

    log_output = StringIO.new
    logger = Logger.new(log_output)

    config = Cellcast::SMS::Configuration.new
    config.sandbox_mode = true
    config.logger = logger

    client = Cellcast.sms(api_key: "test", config: config)
    client.quick_send(to: "+15550000000", message: "Test", from: "TEST")

    log_content = log_output.string
    assert_includes log_content, "Sandbox request"
    assert_includes log_content, "POST"
    assert_includes log_content, "sms/send"
  end

  # Test memory usage doesn't grow with repeated sandbox calls
  def test_sandbox_memory_efficiency
    # Make many calls and ensure no obvious memory leaks
    initial_objects = ObjectSpace.count_objects

    100.times do |i|
      @client.quick_send(to: "+15550000000", message: "Test #{i}", from: "TEST")
    end

    final_objects = ObjectSpace.count_objects

    # Objects should not grow excessively (allowing some growth for normal operation)
    total_growth = final_objects[:TOTAL] - initial_objects[:TOTAL]
    assert total_growth < 10_000, "Memory usage grew too much: #{total_growth} objects"
  end
end
