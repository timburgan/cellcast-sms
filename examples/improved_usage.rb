# frozen_string_literal: true

# Example usage of the improved Cellcast SMS gem architecture
# This demonstrates the simplified developer experience while maintaining full functionality

require 'cellcast'

# Example 1: Simple setup and message sending
puts "=== Example 1: Simple Setup ==="

begin
  # Easy setup with helpful error messages
  client = Cellcast.sms(api_key: 'your-api-key-here')
  
  # Quick send with response objects
  response = client.quick_send(
    to: '+1234567890',
    message: 'Hello from the improved Cellcast gem!',
    from: 'YourBrand'
  )
  
  if response.success?
    puts "✅ Message sent successfully!"
    puts "   Message ID: #{response.message_id}"
    puts "   Status: #{response.status}"
    puts "   Cost: $#{response.cost}"
    puts "   Parts: #{response.parts}"
  end
  
rescue Cellcast::SMS::ValidationError => e
  puts "❌ Validation Error: #{e.message}"
  # Error messages now include helpful guidance:
  # "API key cannot be nil or empty. Get your API key from https://dashboard.cellcast.com/api-keys"
end

# Example 2: Broadcasting with structured responses
puts "\n=== Example 2: Broadcasting ==="

recipients = ['+1234567890', '+1234567891', '+1234567892']

begin
  broadcast_response = client.broadcast(
    to: recipients,
    message: 'Important announcement for all users!',
    from: 'YourBrand'
  )
  
  puts "📢 Broadcast Results:"
  puts "   Total recipients: #{broadcast_response.total_count}"
  puts "   Successful sends: #{broadcast_response.successful_count}"
  puts "   Failed sends: #{broadcast_response.failed_count}"
  puts "   Total cost: $#{broadcast_response.total_cost}"
  
  # Check individual message status
  broadcast_response.messages.each_with_index do |msg, index|
    status_icon = msg.success? ? "✅" : "❌"
    puts "   #{status_icon} #{recipients[index]}: #{msg.status}"
  end
  
rescue Cellcast::SMS::ValidationError => e
  puts "❌ Validation Error: #{e.message}"
  # e.g., "Message too long (1650/1600 characters). Consider splitting into multiple messages."
end

# Example 3: Delivery tracking made simple
puts "\n=== Example 3: Delivery Tracking ==="

message_id = "msg_example_123"

# Simple boolean check
if client.delivered?(message_id: message_id)
  puts "✅ Message was delivered successfully"
else
  # Get detailed status with structured response
  status = client.check_status(message_id: message_id)
  
  if status.pending?
    puts "⏳ Message is still being processed (#{status.status})"
  elsif status.failed?
    puts "❌ Message failed to deliver: #{status.failed_reason}"
  end
end

# Example 4: Incoming messages with conversation tracking
puts "\n=== Example 4: Incoming Messages ==="

# Get unread messages with structured responses
unread = client.unread_messages(limit: 10)

puts "📥 You have #{unread.unread_count} unread messages:"

unread.items.each do |message|
  puts "   From: #{message.from}"
  puts "   Message: #{message.message}"
  puts "   Received: #{message.received_at}"
  
  if message.is_reply?
    puts "   📞 This is a reply to message: #{message.original_message_id}"
    
    # Get conversation history
    conversation = client.conversation_history(
      original_message_id: message.original_message_id
    )
    puts "   💬 Part of #{conversation.total} message conversation"
  end
  
  puts "   ---"
end

# Mark messages as read easily
if unread.items.any?
  message_ids = unread.items.map(&:message_id)
  client.mark_all_read(message_ids: message_ids)
  puts "✅ Marked #{message_ids.length} messages as read"
end

# Example 5: Robust error handling with helpful messages
puts "\n=== Example 5: Error Handling ==="

begin
  # This will demonstrate various error types with helpful messages
  client.quick_send(to: "", message: "test")
  
rescue Cellcast::SMS::ValidationError => e
  puts "❌ Input Validation Error:"
  puts "   #{e.message}"
  # "Phone number cannot be nil or empty. Please provide a valid phone number in international format (e.g., +1234567890)"
  
rescue Cellcast::SMS::AuthenticationError => e
  puts "❌ Authentication Error:"
  puts "   #{e.message}"
  # "Invalid API key or unauthorized access. Please check your API key at https://dashboard.cellcast.com/api-keys"
  
rescue Cellcast::SMS::RateLimitError => e
  puts "⏰ Rate Limited:"
  puts "   #{e.message}"
  if e.retry_after
    puts "   Retry after: #{e.retry_after} seconds"
  end
  
rescue Cellcast::SMS::ServerError => e
  puts "🔧 Server Error:"
  puts "   #{e.message}"
  # "Server error: Internal Server Error. Please try again later or contact support if the issue persists."
  
rescue Cellcast::SMS::NetworkError => e
  puts "🌐 Network Error:"
  puts "   #{e.message}"
  # Automatic retries would have already been attempted
end

# Example 6: Simple webhook setup
puts "\n=== Example 6: Webhook Setup ==="

begin
  # Easy webhook setup for all SMS events
  webhook_response = client.setup_webhook(
    url: 'https://yourapp.com/webhooks/cellcast'
  )
  
  if webhook_response.success?
    puts "✅ Webhook configured successfully"
    puts "   URL: #{webhook_response['url']}"
    puts "   Events: #{webhook_response['events'].join(', ')}"
  end
  
  # Test the webhook
  test_result = client.test_webhook
  puts "🧪 Webhook test: #{test_result.success? ? 'passed' : 'failed'}"
  
rescue Cellcast::SMS::ValidationError => e
  puts "❌ Webhook Configuration Error:"
  puts "   #{e.message}"
  # "URL must be HTTP or HTTPS, got . Example: https://yourapp.com/webhooks"
end

# Example 7: Custom configuration for advanced use cases
puts "\n=== Example 7: Custom Configuration ==="

# Create custom configuration for high-throughput applications
config = Cellcast.configure do |c|
  c.open_timeout = 60        # Longer connection timeout
  c.read_timeout = 120       # Longer read timeout  
  c.max_retries = 5          # More retry attempts
  c.base_delay = 2.0         # Longer base delay
  c.max_delay = 60.0         # Longer max delay
  c.retry_on_rate_limit = true # Always retry rate limits
  c.logger = Logger.new(STDOUT) # Enable detailed logging
end

# Use custom configuration
enterprise_client = Cellcast.sms(
  api_key: 'your-enterprise-api-key',
  config: config
)

puts "🏢 Enterprise client configured with custom retry strategy"

# The convenience methods work with any client configuration
response = enterprise_client.quick_send(
  to: '+1234567890',
  message: 'Enterprise message with robust retry logic'
)

puts "\n=== Summary ==="
puts "✨ The improved architecture provides:"
puts "   • Simple convenience methods for common operations"
puts "   • Structured response objects instead of raw hashes"
puts "   • Helpful error messages with actionable guidance"
puts "   • Comprehensive test coverage for reliability"
puts "   • Backward compatibility with full API access"
puts "   • Robust retry logic with exponential backoff"
puts "   • Extensive error handling for all failure modes"