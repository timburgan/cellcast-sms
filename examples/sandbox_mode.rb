# frozen_string_literal: true

# Example usage of Cellcast SMS gem's sandbox mode
# Perfect for testing and development without incurring API costs

require 'cellcast'

puts "=== Cellcast SMS Sandbox Mode Example ==="
puts

# Example 1: Enable sandbox mode via configuration
puts "1. Setting up sandbox mode..."

config = Cellcast::SMS::Configuration.new
config.sandbox_mode = true  # Enable sandbox mode

client = Cellcast.sms(api_key: "test_api_key", config: config)

puts "✅ Sandbox mode enabled! No live API calls will be made."
puts

# Example 2: Test successful message sending
puts "2. Testing successful message..."

response = client.quick_send(
  to: "+15550000000", # Special test number for success
  message: "This is a test message in sandbox mode!",
  from: "SANDBOX"
)

puts "   Success: #{response['status']}"
puts "   Message ID: #{response.dig('data', 'queueResponse', 0, 'MessageId')}"
puts "   Status: #{response['message']}"
puts "   Valid contacts: #{response.dig('data', 'totalValidContact')}"
puts

# Example 3: Test different failure scenarios
puts "3. Testing failure scenarios with special test numbers..."

# Test failed message
puts "   Testing failed send (+15550000001):"
failed_response = client.quick_send(
  to: "+15550000001", # Special test number for failure
  message: "This will fail",
  from: "SANDBOX"
)
puts "   Success: #{failed_response['status']}"
puts "   Status: #{failed_response['message']}"
puts "   Error details: #{failed_response['error']}"
puts

# Test rate limiting
puts "   Testing rate limit (+15550000002):"
begin
  client.quick_send(to: "+15550000002", message: "Rate limited")
rescue Cellcast::SMS::RateLimitError => e
  puts "   ⏰ Rate limit error (as expected): #{e.message}"
  puts "   Retry after: #{e.retry_after} seconds"
end
puts

# Test invalid number
puts "   Testing invalid number (+15550000003):"
begin
  client.quick_send(to: "+15550000003", message: "Invalid number")
rescue Cellcast::SMS::ValidationError => e
  puts "   ❌ Validation error (as expected): #{e.message}"
end
puts

# Test insufficient credits
puts "   Testing insufficient credits (+15550000004):"
begin
  client.quick_send(to: "+15550000004", message: "Insufficient credits")
rescue Cellcast::SMS::APIError => e
  puts "   💳 API error (as expected): #{e.message}"
end
puts

# Example 4: Broadcast testing
puts "4. Testing broadcast with mixed results..."

broadcast_response = client.broadcast(
  to: ["+15550000000", "+15550000001", "+15551234567"], # Mix of success, failure, and normal
  message: "Broadcast test in sandbox mode",
  from: "SANDBOX"
)

puts "   Total messages: #{broadcast_response.dig('data', 'totalValidContact') + broadcast_response.dig('data', 'totalInvalidContact')}"
puts "   Successful: #{broadcast_response.dig('data', 'totalValidContact')}"
puts "   Failed: #{broadcast_response.dig('data', 'totalInvalidContact')}"
puts "   Status: #{broadcast_response['status'] ? 'Success' : 'Failed'}"
puts

# Example 5: Status checking
puts "5. Testing message status checking..."

# Different message ID patterns trigger different statuses
delivered_status = client.check_status(message_id: "delivered_msg_123")
failed_status = client.check_status(message_id: "fail_msg_456")
pending_status = client.check_status(message_id: "pending_msg_789")

puts "   Delivered message: #{delivered_status['status']} (#{delivered_status.dig('data', 'status')})"
puts "   Failed message: #{failed_status['status']} (#{failed_status.dig('data', 'status')})"
puts "   Pending message: #{pending_status['status']} (#{pending_status.dig('data', 'status')})"
puts

# Example 6: Incoming messages
puts "6. Testing incoming messages..."

unread = client.unread_messages
puts "   Unread messages: #{unread.dig('data', 'messages')&.length || 0}"

messages = unread.dig('data', 'messages') || []
messages.each do |message|
  puts "   From: #{message['from']} - '#{message['message']}'"
  puts "   Is reply: #{message['is_reply']}"
  puts "   Original message ID: #{message['original_message_id']}" if message['is_reply']
end
puts

# Example 7: Webhook testing
puts "7. Testing webhook setup..."

webhook_response = client.setup_webhook(
  url: "https://example.com/webhook",
  events: ["sms.delivered", "sms.received"]
)

puts "   Webhook setup success: #{webhook_response['status']}"
puts "   Webhook ID: #{webhook_response.dig('data', 'webhook_id')}"

test_result = client.test_webhook
puts "   Webhook test: #{test_result['status'] ? 'passed' : 'failed'}"
puts

# Example 8: Using with testing frameworks
puts "8. Example for testing frameworks..."

puts <<~EXAMPLE
   # In your test files:
   
   def setup
     config = Cellcast::SMS::Configuration.new
     config.sandbox_mode = true
     @client = Cellcast.sms(api_key: "test_key", config: config)
   end
   
   def test_successful_sms_sending
     response = @client.quick_send(
       to: "+15550000000",  # Always succeeds in sandbox
       message: "Test message"
     )
     assert response['status']
     assert_equal "Request is being processed", response['message']
   end
   
   def test_failed_sms_handling
     response = @client.quick_send(
       to: "+15550000001",  # Always fails in sandbox
       message: "Test message"
     )
     refute response['status']
     assert response['error']
   end
   
   def test_rate_limiting_handling
     assert_raises(Cellcast::SMS::RateLimitError) do
       @client.quick_send(
         to: "+15550000002",  # Always rate limited in sandbox
         message: "Test message"
       )
     end
   end

EXAMPLE

puts "=== Sandbox Test Numbers Summary ==="
puts
puts "Special phone numbers that trigger specific behaviors:"
puts "  +15550000000 → ✅ Success (queued status)"
puts "  +15550000001 → ❌ Failed (failed status)"
puts "  +15550000002 → ⏰ Rate Limited (throws RateLimitError)"
puts "  +15550000003 → 🚫 Invalid Number (throws ValidationError)"
puts "  +15550000004 → 💳 Insufficient Credits (throws APIError)"
puts "  Any other number → ✅ Success (default behavior)"
puts
puts "=== Benefits of Sandbox Mode ==="
puts "✨ Test your integration without API costs"
puts "🔧 Consistent, predictable responses for testing"
puts "🎯 Special test numbers for error scenario testing"
puts "🔄 Exercises all the same code paths as live mode"
puts "📊 Realistic response structures and timing"
puts

puts "🏁 Sandbox mode demonstration complete!"
puts "💡 Remember to disable sandbox mode in production!"