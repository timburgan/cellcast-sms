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
  
  if response['meta'] && response['meta']['status'] == 'SUCCESS'
    puts "✅ Message sent successfully!"
    messages = response.dig('data', 'messages')
    if messages && messages.first
      message = messages.first
      puts "   Message ID: #{message['message_id']}"
      puts "   To: #{message['to']}"
      puts "   From: #{message['from']}"
      puts "   Body: #{message['body']}"
      puts "   Date: #{message['date']}"
    end
    puts "   API Message: #{response['msg']}"
    puts "   Total Numbers: #{response.dig('data', 'total_numbers')}"
    puts "   Success Numbers: #{response.dig('data', 'success_number')}"
    puts "   Credits Used: #{response.dig('data', 'credits_used')}"
  else
    puts "❌ Message failed to send"
    puts "   Error: #{response['msg']}" if response['msg']
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
  
  if broadcast_response['meta'] && broadcast_response['meta']['status'] == 'SUCCESS'
    data = broadcast_response['data']
    puts "   Total numbers: #{data['total_numbers']}"
    puts "   Success numbers: #{data['success_number']}"
    puts "   Credits used: #{data['credits_used']}"
    puts "   API Message: #{broadcast_response['msg']}"
    
    # Show individual messages
    data['messages'].each do |message|
      puts "   ✅ #{message['to']}: Message ID #{message['message_id']}"
    end
  else
    puts "   ❌ Broadcast failed: #{broadcast_response['msg']}"
  end
  
rescue Cellcast::SMS::ValidationError => e
  puts "❌ Validation Error: #{e.message}"
  # e.g., "Message too long (1650/1600 characters). Consider splitting into multiple messages."
end

# Example 3: Account Management
puts "\n=== Example 3: Account Management ==="

# Check account balance
balance = client.balance
if balance['meta'] && balance['meta']['status'] == 'SUCCESS'
  puts "💰 Current balance:"
  puts "   SMS Balance: $#{balance.dig('data', 'sms_balance') || 'Unknown'}"
  puts "   MMS Balance: $#{balance.dig('data', 'mms_balance') || 'Unknown'}"
  puts "   Account Name: #{balance.dig('data', 'account_name') || 'Unknown'}"
  puts "   Account Email: #{balance.dig('data', 'account_email') || 'Unknown'}"
else
  puts "❌ Failed to get balance: #{balance['msg']}"
end

# Get templates
templates = client.get_templates
if templates['meta'] && templates['meta']['status'] == 'SUCCESS'
  puts "📋 Available Templates: #{templates['data'].length} templates found"
  templates['data'].each do |template|
    puts "   Template ID: #{template['id']} - #{template['name']}"
  end
else
  puts "❌ Failed to get templates: #{templates['msg']}"
end

# Example 4: Sender ID Management
puts "\n=== Example 4: Sender ID Management ==="

begin
  # Register an Alpha ID (business name)
  alpha_response = client.register_alpha_id(
    alpha_id: 'YourBrand',
    purpose: 'Marketing and notifications'
  )
  
  if alpha_response['meta'] && alpha_response['meta']['status'] == 'SUCCESS'
    puts "🏢 Alpha ID registration: Success"
    puts "   Message: #{alpha_response['msg']}"
  else
    puts "❌ Alpha ID registration failed: #{alpha_response['msg']}"
  end
  
rescue Cellcast::SMS::APIError => e
  puts "❌ Registration Error: #{e.message}"
  puts "   Attempted URL: #{e.requested_url}"
end

# Example 5: Get Message Status and Inbound Messages
puts "\n=== Example 5: Message Status and Inbound Messages ==="

begin
  # Get status of a sent message (requires actual message ID)
  # status_response = client.get_message_status(message_id: 'actual_message_id_here')
  # puts "📋 Message Status: #{status_response['msg']}"
  
  # Get inbound messages
  inbound_response = client.get_inbound_messages(page: 1)
  
  if inbound_response['meta'] && inbound_response['meta']['status'] == 'SUCCESS'
    puts "📨 Inbound Messages:"
    if inbound_response['data'] && inbound_response['data'].any?
      inbound_response['data'].each do |message|
        puts "   From: #{message['from']} - #{message['body']}"
        puts "   Date: #{message['date']}"
        puts "   Message ID: #{message['message_id']}"
      end
    else
      puts "   No inbound messages found"
    end
  else
    puts "❌ Failed to get inbound messages: #{inbound_response['msg']}"
  end
  
rescue Cellcast::SMS::APIError => e
  puts "❌ Error getting messages: #{e.message}"
end

# Example 6: New Zealand SMS
puts "\n=== Example 6: New Zealand SMS ==="

begin
  nz_response = client.send_to_nz(
    to: '+64211234567',  # New Zealand number
    message: 'Hello from New Zealand API!',
    from: 'YourBrand'
  )
  
  if nz_response['meta'] && nz_response['meta']['status'] == 'SUCCESS'
    puts "✅ New Zealand SMS sent successfully!"
    puts "   Message: #{nz_response['msg']}"
  else
    puts "❌ New Zealand SMS failed: #{nz_response['msg']}"
  end
  
rescue Cellcast::SMS::APIError => e
  puts "❌ NZ SMS Error: #{e.message}"
end

# Example 7: Robust error handling with helpful messages
puts "\n=== Example 7: Error Handling ==="

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

# Example 8: Custom configuration for advanced use cases
puts "\n=== Example 8: Custom Configuration ==="

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