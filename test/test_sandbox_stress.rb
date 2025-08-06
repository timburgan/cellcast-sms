# frozen_string_literal: true

require "test_helper"

class TestSandboxStress < Minitest::Test
  def setup
    @config = Cellcast::SMS::Configuration.new
    @config.sandbox_mode = true
    @client = Cellcast.sms(api_key: "test_api_key", config: @config)
  end

  # Test high volume operations
  def test_high_volume_sandbox_operations
    # Send many messages rapidly
    100.times do |i|
      response = @client.quick_send(to: "+15550000000", message: "Test #{i}", from: "TEST")
      assert response.success?, "Message #{i} should succeed"
      assert response.message_id.start_with?("sandbox_"), "Message ID should be sandbox format"
    end
  end

  # Test mixed success/failure scenarios at scale
  def test_bulk_mixed_scenarios
    # Create a large mix of different test numbers
    recipients = []
    
    # Add various test numbers multiple times
    20.times do
      recipients += [
        "+15550000000",  # Success
        "+15550000001",  # Failure
        "+15551234567"   # Default success
      ]
    end
    
    response = @client.broadcast(to: recipients, message: "Bulk test", from: "TEST")
    assert_equal 60, response.total_count
    assert_equal 40, response.successful_count  # 2/3 should succeed
    assert_equal 20, response.failed_count      # 1/3 should fail
  end

  # Test error scenarios at high volume
  def test_error_scenarios_high_volume
    # Test rate limiting errors in bulk
    error_count = 0
    20.times do
      begin
        @client.quick_send(to: "+15550000002", message: "Rate limit test", from: "TEST")
        flunk "Should have raised RateLimitError"
      rescue Cellcast::SMS::RateLimitError => e
        error_count += 1
        assert_equal 429, e.status_code
        assert_equal 60, e.retry_after
      end
    end
    assert_equal 20, error_count
    
    # Test validation errors in bulk
    error_count = 0
    20.times do
      begin
        @client.quick_send(to: "+15550000003", message: "Invalid test", from: "TEST")
        flunk "Should have raised ValidationError"
      rescue Cellcast::SMS::ValidationError => e
        error_count += 1
        assert_includes e.message, "Invalid phone number format"
      end
    end
    assert_equal 20, error_count
  end

  # Test boundary values extensively
  def test_boundary_value_stress
    # Test at exact message length limit
    exact_limit_message = "a" * 1600
    response = @client.quick_send(to: "+15550000000", message: exact_limit_message, from: "TEST")
    assert response.success?
    
    # Test just over limit multiple times
    5.times do |i|
      over_limit_message = "a" * (1601 + i)
      assert_raises(Cellcast::SMS::ValidationError) do
        @client.quick_send(to: "+15550000000", message: over_limit_message, from: "TEST")
      end
    end
    
    # Test very short messages
    ["a", "ab", "abc"].each do |short_msg|
      response = @client.quick_send(to: "+15550000000", message: short_msg, from: "TEST")
      assert response.success?
    end
  end

  # Test unicode and special characters
  def test_unicode_stress
    unicode_messages = [
      "Hello 🌍 World",
      "こんにちは 世界",
      "Здравствуй мир",
      "مرحبا بالعالم",
      "🚀🎉🎯💫⚡🔥💯",
      "Math: ∑∞≠±÷×≈∆",
      "Quotes: \"''«»‚„\"",
      "Symbols: ©®™€£¥"
    ]
    
    unicode_messages.each do |msg|
      response = @client.quick_send(to: "+15550000000", message: msg, from: "TEST")
      assert response.success?, "Unicode message should work: #{msg}"
    end
  end

  # Test all API endpoints under stress
  def test_all_endpoints_stress
    10.times do |i|
      # SMS operations
      @client.sms.send_message(to: "+15550000000", message: "Test #{i}")
      @client.sms.send_bulk(messages: [{ to: "+15550000000", message: "Bulk #{i}" }])
      @client.sms.get_status(message_id: "test_#{i}")
      @client.sms.get_delivery_report(message_id: "test_#{i}")
      @client.sms.list_messages(limit: 10)
      
      # Incoming operations
      @client.incoming.list_incoming(limit: 10)
      @client.incoming.mark_as_read(message_ids: ["msg_#{i}"])
      @client.incoming.get_replies(original_message_id: "orig_#{i}")
      
      # Webhook operations
      @client.webhook.configure_webhook(url: "https://example#{i}.com/webhook", events: ["sms.sent"])
      @client.webhook.test_webhook
      
      # Sender ID operations
      @client.sender_id.list_sender_ids
      
      # Token operations
      @client.token.verify_token
    end
  end

  # Test concurrent access simulation
  def test_concurrent_simulation
    # Simulate concurrent access by creating multiple clients
    clients = 10.times.map do |i|
      config = Cellcast::SMS::Configuration.new
      config.sandbox_mode = true
      Cellcast.sms(api_key: "test_client_#{i}", config: config)
    end
    
    # Each client performs operations
    results = clients.map.with_index do |client, i|
      [
        client.quick_send(to: "+15550000000", message: "Client #{i}", from: "TEST"),
        client.check_status(message_id: "test_#{i}"),
        client.unread_messages
      ]
    end
    
    # All should succeed
    results.each_with_index do |(send_response, status_response, unread_response), i|
      assert send_response.success?, "Client #{i} send should succeed"
      assert status_response.status, "Client #{i} status should have status"
      assert unread_response.items, "Client #{i} unread should have items"
    end
  end

  # Test malformed requests thoroughly
  def test_malformed_requests_stress
    # Various invalid phone number formats
    invalid_phones = [
      "123456789",      # No +
      "+",              # Just +
      "+0123456789",    # Starts with 0
      "+123",           # Too short
      "+1" + "9" * 20,  # Too long
      "++1234567890",   # Double +
      "+1-234-567-890", # With dashes
      "+1 234 567 890", # With spaces (internal)
      "abc123",         # Letters
      "😀123456789",     # Emoji
    ]
    
    invalid_phones.each do |phone|
      assert_raises(Cellcast::SMS::ValidationError) do
        @client.quick_send(to: phone, message: "Test", from: "TEST")
      end
    end
    
    # Various invalid message types
    invalid_messages = [
      nil,
      "",
      "   ",
      123,
      [],
      {},
      true,
      false
    ]
    
    invalid_messages.each do |message|
      assert_raises(Cellcast::SMS::ValidationError) do
        @client.quick_send(to: "+15550000000", message: message, from: "TEST")
      end
    end
  end

  # Test response consistency
  def test_response_consistency
    # Same request should produce consistent response structure
    10.times do
      response = @client.quick_send(to: "+15550000000", message: "Consistency test", from: "TEST")
      
      # Check structure consistency
      assert response.raw_response['id']
      assert response.raw_response['message_id']
      assert response.raw_response['to']
      assert response.raw_response['status']
      assert response.raw_response['cost']
      assert response.raw_response['parts']
      assert response.raw_response['created_at']
      
      # Check types consistency
      assert response.raw_response['id'].is_a?(String)
      assert response.raw_response['message_id'].is_a?(String)
      assert response.raw_response['to'].is_a?(String)
      assert response.raw_response['status'].is_a?(String)
      assert response.raw_response['cost'].is_a?(Numeric)
      assert response.raw_response['parts'].is_a?(Integer)
      assert response.raw_response['created_at'].is_a?(String)
      
      # Check format consistency
      assert_match(/^sandbox_\d+_\d+$/, response.raw_response['message_id'])
      assert_match(/^\+\d+$/, response.raw_response['to'])
      assert_match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/, response.raw_response['created_at'])
    end
  end

  # Test memory stability under load
  def test_memory_stability
    # Baseline measurement
    GC.start
    initial_objects = ObjectSpace.count_objects
    
    # Perform many operations
    500.times do |i|
      @client.quick_send(to: "+15550000000", message: "Memory test #{i}", from: "TEST")
      @client.check_status(message_id: "test_#{i}")
      @client.unread_messages
      
      # Trigger GC periodically
      GC.start if i % 100 == 0
    end
    
    # Final measurement
    GC.start
    final_objects = ObjectSpace.count_objects
    
    # Memory growth should be reasonable
    growth = final_objects[:TOTAL] - initial_objects[:TOTAL]
    assert growth < 50000, "Memory growth too high: #{growth} objects"
  end

  # Test edge cases in bulk operations
  def test_bulk_edge_cases_stress
    # Maximum recipients (boundary testing) - 1000 should be OK, 1001 should fail
    max_recipients = Array.new(1001) { |i| "+1555000#{i.to_s.rjust(4, '0')}" }
    
    # Should handle large bulk but this should hit validation limits (1001 > 1000)
    assert_raises(Cellcast::SMS::ValidationError) do
      @client.broadcast(to: max_recipients, message: "Over max test", from: "TEST")
    end
    
    # Test exactly at maximum that should work (1000)
    exactly_max_recipients = Array.new(1000) { |i| "+1555000#{i.to_s.rjust(4, '0')}" }
    response = @client.broadcast(to: exactly_max_recipients, message: "Exactly max test", from: "TEST")
    assert_equal 1000, response.total_count
    
    # Test near-maximum that should definitely work
    near_max_recipients = Array.new(100) { |i| "+1555000#{i.to_s.rjust(4, '0')}" }
    response = @client.broadcast(to: near_max_recipients, message: "Near max test", from: "TEST")
    assert_equal 100, response.total_count
    
    # Test mixed special numbers in bulk
    mixed_recipients = Array.new(50) { |i| 
      case i % 5
      when 0 then "+15550000000"  # Success
      when 1 then "+15550000001"  # Failure
      when 2 then "+15551234567"  # Default success
      when 3 then "+15551111111"  # Default success
      when 4 then "+15552222222"  # Default success
      end
    }
    
    response = @client.broadcast(to: mixed_recipients, message: "Mixed test", from: "TEST")
    assert_equal 50, response.total_count
    assert_equal 40, response.successful_count  # 4/5 should succeed
    assert_equal 10, response.failed_count      # 1/5 should fail
  end
end