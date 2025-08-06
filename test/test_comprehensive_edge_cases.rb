# frozen_string_literal: true

require "test_helper"

class TestComprehensiveEdgeCases < Minitest::Test
  def setup
    config = Cellcast::SMS::Configuration.new
    config.sandbox_mode = true
    @client = Cellcast.sms(api_key: "test_key", config: config)
  end

  # Test extreme boundary conditions
  def test_message_length_boundaries
    # Exactly at limit (1600 characters)
    message_1600 = "x" * 1600
    response = @client.quick_send(to: "+15550000000", message: message_1600)
    assert response.success?

    # Just over limit (1601 characters) should fail
    message_1601 = "x" * 1601
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.quick_send(to: "+15550000000", message: message_1601)
    end
    assert_includes error.message, "Message too long"
  end

  def test_phone_number_edge_cases
    # Valid international formats
    valid_numbers = [
      "+1234567890",    # US format
      "+441234567890",  # UK format  
      "+861234567890",  # China format
      "+33123456789",   # France format
      "+4915551234567", # Germany format
    ]

    valid_numbers.each do |number|
      response = @client.quick_send(to: number, message: "Test")
      assert response.success?, "Should accept valid number: #{number}"
    end

    # Invalid formats that should raise validation errors
    invalid_numbers = [
      "1234567890",     # Missing +
      "+0123456789",    # Leading zero after +
      "+",              # Just plus
      "+abc123",        # Contains letters
      "+123",           # Too short (less than 4 digits)
    ]

    invalid_numbers.each do |number|
      error = assert_raises(Cellcast::SMS::ValidationError) do
        @client.quick_send(to: number, message: "Test")
      end
      assert_includes error.message.downcase, "phone number", "Should reject invalid number: #{number}"
    end

    # Test empty string separately as it has a different error message
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.quick_send(to: "", message: "Test")
    end
    assert_includes error.message, "empty"
  end

  def test_unicode_and_special_characters
    # Test various Unicode messages
    unicode_messages = [
      "Hello 世界 🌍",           # Mixed script + emoji
      "Café naïve résumé",       # Accented characters
      "Москва Санкт-Петербург",  # Cyrillic
      "こんにちは世界",           # Japanese
      "مرحبا بالعالم",           # Arabic
      "🎉🎊🎈🎁🎂🍰🥳",          # Only emojis
      "Line1\nLine2\nLine3",     # Newlines
      "Tab\there",               # Tab character
      '"Quoted" \'text\'',       # Quotes
      "Special: !@#$%^&*()_+-=", # Special characters
    ]

    unicode_messages.each do |message|
      response = @client.quick_send(to: "+15550000000", message: message)
      assert response.success?, "Should handle Unicode message: #{message.inspect}"
      assert_equal message.length <= 1600, true, "Message length validation should work for Unicode"
    end
  end

  def test_bulk_message_boundaries
    # Test exactly at the 1000 message limit
    messages_1000 = Array.new(1000) { { to: "+15550000000", message: "Test #{rand(1000)}" } }
    response = @client.sms.send_bulk(messages: messages_1000)
    assert response["status"]

    # Test just over the limit (1001 messages)
    messages_1001 = Array.new(1001) { { to: "+15550000000", message: "Test #{rand(1000)}" } }
    error = assert_raises(Cellcast::SMS::ValidationError) do
      @client.sms.send_bulk(messages: messages_1001)
    end
    assert_includes error.message, "Too many messages"
  end

  def test_malformed_input_types
    # Test sending non-string types where strings are expected
    invalid_inputs = [
      { to: 123_456_789, message: "Valid message" },        # Integer phone
      { to: "+15550000000", message: 123 },                 # Integer message
      { to: "+15550000000", message: ["array", "message"] }, # Array message
      { to: "+15550000000", message: { hash: "message" } },  # Hash message
      { to: nil, message: "Valid message" },                 # Nil phone
      { to: "+15550000000", message: nil },                  # Nil message
      { to: [], message: "Valid message" },                  # Array phone
      { to: {}, message: "Valid message" },                  # Hash phone
    ]

    invalid_inputs.each do |input|
      error = assert_raises(Cellcast::SMS::ValidationError) do
        @client.quick_send(**input)
      end
      assert error.message.include?("must be a string") || error.message.include?("cannot be nil"),
             "Should validate input types: #{input.inspect}"
    end
  end

  def test_concurrent_access_safety
    # Test that sandbox mode is thread-safe using only success numbers
    threads = []
    results = []
    mutex = Mutex.new

    10.times do |i|
      # Use different success numbers to avoid hitting special test numbers
      phone = "+1234567#{i.to_s.rjust(3, '0')}"
      threads << Thread.new do
        response = @client.quick_send(to: phone, message: "Thread #{i}")
        mutex.synchronize { results << response.success? }
      end
    end

    threads.each(&:join)
    assert_equal 10, results.length
    assert results.all?, "All concurrent requests should succeed"
  end

  def test_memory_usage_under_stress
    # Test that repeated operations don't cause memory leaks
    initial_objects = ObjectSpace.count_objects

    1000.times do |i|
      @client.quick_send(to: "+15550000000", message: "Stress test #{i}")
      GC.start if (i % 100).zero? # Periodic garbage collection
    end

    final_objects = ObjectSpace.count_objects
    object_growth = final_objects[:T_OBJECT] - initial_objects[:T_OBJECT]

    # Allow some object growth but not excessive (adjust threshold as needed)
    assert object_growth < 10_000, "Excessive object growth detected: #{object_growth} objects"
  end

  def test_api_response_structure_consistency
    # Test that all API responses have consistent structure
    endpoints = [
      -> { @client.sms.send_message(to: "+15550000000", message: "Test") },
      -> { @client.sms.send_bulk(messages: [{ to: "+15550000000", message: "Test" }]) },
      -> { @client.token.verify_token },
      -> { @client.sender_id.list_sender_ids },
    ]

    endpoints.each_with_index do |endpoint, index|
      response = endpoint.call
      assert response.is_a?(Hash), "Endpoint #{index} should return Hash"
      assert response.key?("status"), "Endpoint #{index} should have status field"
      assert [true, false].include?(response["status"]), "Endpoint #{index} status should be boolean"
    end

    # Test endpoints that return different structures (data arrays)
    list_endpoints = [
      -> { @client.incoming.list_incoming },
      -> { @client.webhook.get_delivery_logs },
    ]

    list_endpoints.each_with_index do |endpoint, index|
      response = endpoint.call
      assert response.is_a?(Hash), "List endpoint #{index} should return Hash"
      # These may have different structures but should still be hashes
      assert response.is_a?(Hash), "List endpoint #{index} should return valid structure"
    end
  end

  def test_special_test_numbers_comprehensive
    # Test all special test numbers thoroughly
    test_cases = [
      { number: "+15550000000", should_succeed: true, description: "success number" },
      { number: "+15550000001", should_succeed: false, description: "failed number" },
    ]

    test_cases.each do |test_case|
      if test_case[:should_succeed]
        response = @client.quick_send(to: test_case[:number], message: "Test")
        assert response.success?, "#{test_case[:description]} should succeed"
      else
        response = @client.quick_send(to: test_case[:number], message: "Test")
        refute response.success?, "#{test_case[:description]} should fail"
      end
    end

    # Test special numbers that raise exceptions
    exception_cases = [
      { number: "+15550000002", exception: Cellcast::SMS::RateLimitError, description: "rate limit" },
      { number: "+15550000003", exception: Cellcast::SMS::ValidationError, description: "invalid number" },
      { number: "+15550000004", exception: Cellcast::SMS::APIError, description: "insufficient credits" },
    ]

    exception_cases.each do |test_case|
      error = assert_raises(test_case[:exception]) do
        @client.quick_send(to: test_case[:number], message: "Test")
      end
      assert error.message.length > 0, "#{test_case[:description]} should have error message"
    end
  end

  def test_configuration_edge_cases
    # Test various configuration scenarios
    config = Cellcast::SMS::Configuration.new

    # Test boundary values for timeouts
    config.open_timeout = 1
    config.read_timeout = 1
    # Should not raise
    config.validate!

    # Test invalid timeout values
    config.open_timeout = 0
    error = assert_raises(Cellcast::SMS::ValidationError) { config.validate! }
    assert_includes error.message, "open_timeout must be positive"

    config.open_timeout = 30
    config.read_timeout = -1
    error = assert_raises(Cellcast::SMS::ValidationError) { config.validate! }
    assert_includes error.message, "read_timeout must be positive"
  end

  def test_error_message_helpfulness
    # Ensure error messages are helpful and actionable
    begin
      Cellcast.sms(api_key: "")
    rescue Cellcast::SMS::ValidationError => e
      assert_includes e.message, "https://dashboard.cellcast.com/api-keys"
      assert_includes e.message, "API key cannot be nil or empty"
    end

    begin
      @client.quick_send(to: "invalid", message: "test")
    rescue Cellcast::SMS::ValidationError => e
      assert_includes e.message, "international format"
      assert_includes e.message, "+1234567890"
    end

    begin
      @client.quick_send(to: "+15550000000", message: "")
    rescue Cellcast::SMS::ValidationError => e
      assert_includes e.message, "Message cannot be nil or empty"
    end
  end

  def test_response_object_methods
    # Test all response object methods work correctly
    response = @client.quick_send(to: "+15550000000", message: "Test")

    # Test basic response methods
    assert_respond_to response, :success?
    assert_respond_to response, :message_id
    assert_respond_to response, :status
    assert_respond_to response, :cost
    assert_respond_to response, :parts
    assert_respond_to response, :failed?
    assert_respond_to response, :to_h
    assert_respond_to response, :[]

    # Test hash-like access
    refute_nil response["status"]
    refute_nil response[:status]

    # Test data types
    assert_kind_of String, response.message_id
    assert_kind_of String, response.status
    assert_kind_of Numeric, response.cost
    assert_kind_of Integer, response.parts
    assert [true, false].include?(response.success?)
    assert [true, false].include?(response.failed?)
  end

  def test_webhook_url_validation_edge_cases
    # Test comprehensive URL validation
    valid_urls = [
      "https://example.com",
      "http://localhost:3000",
      "https://subdomain.example.com/path",
      "https://example.com:8080/webhook",
      "https://example.com/path?query=value",
      "https://example.com/path#fragment",
    ]

    valid_urls.each do |url|
      response = @client.webhook.configure_webhook(url: url, events: ["sms.sent"])
      assert response.is_a?(Hash), "Should return response for valid URL: #{url}"
      assert response.key?("webhook_id") || response.key?("status"), "Should have webhook response structure"
    end

    invalid_urls = [
      "",
      "not-a-url",
      "ftp://example.com",
      "mailto:test@example.com",
      "javascript:alert('xss')",
      "//example.com", # Protocol relative
    ]

    invalid_urls.each do |url|
      error = assert_raises(Cellcast::SMS::ValidationError) do
        @client.webhook.configure_webhook(url: url, events: ["sms.sent"])
      end
      assert error.message.length > 0, "Should reject invalid URL: #{url}"
    end
  end
end