# frozen_string_literal: true

# Example usage of the Cellcast SMS gem with official API endpoints only
# This demonstrates SMS sending, account management, and sender ID registration

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
  
  if response['status']
    puts "✅ Message sent successfully!"
    queue_response = response.dig('data', 'queueResponse', 0)
    if queue_response
      puts "   Message ID: #{queue_response['MessageId']}"
      puts "   Result: #{queue_response['Result']}"
      puts "   Contact: #{queue_response['Contact']}"
    end
    puts "   API Message: #{response['message']}"
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
  
  if broadcast_response['status']
    data = broadcast_response['data']
    puts "   Total valid contacts: #{data['totalValidContact']}"
    puts "   Total invalid contacts: #{data['totalInvalidContact']}"
    puts "   API Message: #{broadcast_response['message']}"
    
    # Show individual queue responses
    data['queueResponse'].each do |queue_item|
      puts "   ✅ #{queue_item['Contact']}: #{queue_item['Result']}"
    end
    
    # Show invalid contacts
    data['invalidContacts'].each do |invalid|
      puts "   ❌ #{invalid}: Invalid contact"
    end
  else
    puts "   ❌ Broadcast failed: #{broadcast_response['message']}"
  end
  
rescue Cellcast::SMS::ValidationError => e
  puts "❌ Validation Error: #{e.message}"
  # e.g., "Message too long (1650/1600 characters). Consider splitting into multiple messages."
end

# Example 3: Account Management
puts "\n=== Example 3: Account Management ==="

# Check account balance
balance = client.balance
puts "💰 Current balance: $#{balance.dig('data', 'balance') || 'Unknown'}"

# Get usage statistics
usage = client.usage_report
puts "📊 Usage Statistics:"
puts "   Messages sent: #{usage.dig('data', 'messages_sent') || 'Unknown'}"
puts "   Total cost: $#{usage.dig('data', 'total_cost') || 'Unknown'}"

# Example 4: Sender ID Management
puts "\n=== Example 4: Sender ID Management ==="

begin
  # Register a business name
  business_response = client.sender_id.register_business_name(
    business_name: 'Your Company Ltd',
    business_registration: 'REG123456',
    contact_info: {
      email: 'contact@yourcompany.com',
      phone: '+1234567890'
    }
  )
  
  puts "🏢 Business registration status: #{business_response['status'] ? 'Success' : 'Failed'}"
  puts "   Message: #{business_response['message']}"
  
  # Register a custom number
  number_response = client.sender_id.register_custom_number(
    phone_number: '+1234567890',
    purpose: 'Customer support notifications'
  )
  
  puts "📞 Custom number registration: #{number_response['status'] ? 'Success' : 'Failed'}"
  puts "   Message: #{number_response['message']}"
  
rescue Cellcast::SMS::APIError => e
  puts "❌ Registration Error: #{e.message}"
  puts "   Attempted URL: #{e.requested_url}"
end

# Example 5: Message Cancellation
puts "\n=== Example 5: Message Cancellation ==="

begin
  # Cancel a scheduled message
  cancel_response = client.cancel_message(message_id: 'msg_example_123')
  
  if cancel_response['status']
    puts "✅ Message cancelled successfully"
    puts "   Message: #{cancel_response['message']}"
  else
    puts "❌ Could not cancel message: #{cancel_response['message']}"
  end
  
rescue Cellcast::SMS::APIError => e
  puts "❌ Cancellation Error: #{e.message}"
  puts "   This may mean the message was already sent"
  puts "   Attempted URL: #{e.requested_url}"
end

# Example 6: Robust error handling with helpful messages
puts "\n=== Example 6: Error Handling ==="

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
  puts "   Attempted URL: #{e.requested_url}"
  if e.retry_after
    puts "   Retry after: #{e.retry_after} seconds"
  end
  
rescue Cellcast::SMS::ServerError => e
  puts "🔧 Server Error:"
  puts "   #{e.message}"
  puts "   Attempted URL: #{e.requested_url}"
  # "Server error: Internal Server Error. Please try again later or contact support if the issue persists."
  
rescue Cellcast::SMS::NetworkError => e
  puts "🌐 Network Error:"
  puts "   #{e.message}"
  puts "   Attempted URL: #{e.requested_url}"
  # Automatic retries would have already been attempted
end

# Example 7: Custom configuration for advanced use cases
puts "\n=== Example 7: Custom Configuration ==="

# Create custom configuration for high-throughput applications
config = Cellcast.configure do |c|
  c.open_timeout = 60        # Longer connection timeout
  c.read_timeout = 120       # Longer read timeout  
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
puts "✨ The updated gem architecture provides:"
puts "   • Simple convenience methods for common operations"
puts "   • Raw API responses for direct access to all data"
puts "   • Helpful error messages with actionable guidance"
puts "   • Comprehensive test coverage for reliability"
puts "   • Direct alignment with official Cellcast API"
puts "   • Robust retry logic with exponential backoff"
puts "   • Extensive error handling for all failure modes"