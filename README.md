# Cellcast SMS

> **Note**: This is an unofficial gem that wraps the [official Cellcast API](https://cellcast.com.au/api/documentation/). I built this for my own use to make my life easier.

A Ruby gem for the Cellcast API focused on SMS sending and account management. Provides an enhanced developer experience with smart response objects while maintaining full access to the official Cellcast API.

## Features

### Core SMS Operations
- **Send SMS**: Individual messages with enhanced response objects
- **Bulk SMS**: Send to multiple recipients with automatic chunking
- **Account Management**: Check balance with low-balance detection
- **Message Tracking**: Get message details with delivery tracking
- **Inbound Messages**: Retrieve and manage incoming SMS with pagination helpers
- **New Zealand SMS**: Dedicated endpoint for NZ numbers
- **Template Messages**: Send SMS using predefined templates
- **Alpha ID Registration**: Register business names for sender IDs

### Enhanced Developer Experience
- **Smart Response Objects**: Convenient methods like `.success?`, `.message_id`, `.credits_used`
- **Chainable Operations**: `.on_success` and `.on_error` for clean error handling
- **Automatic Retry**: Built-in retry logic for rate limits and server errors
- **Smart Defaults**: Configure default sender IDs and other preferences
- **Automatic Chunking**: Large broadcasts split automatically for optimal delivery
- **Message Tracking**: Track messages until delivered with timeout support
- **Pagination Helpers**: Easy iteration through large inbound message lists
- **Low Balance Alerts**: Automatic detection of low account balances

### Configuration Options
- **Enhanced Responses**: Rich response objects with convenience methods (default)
- **Raw Responses**: Direct API responses for maximum compatibility
- **Flexible Configuration**: Custom retry settings, chunk sizes, and more
- **Sandbox Mode**: Safe testing without real API calls

## Quick Start

### Installation

Add to your Gemfile:

```ruby
gem 'cellcast-sms'
```

Then run:
```bash
bundle install
```

### Enhanced Response Mode (Recommended)

```ruby
require 'cellcast'

# Create client with enhanced responses (default behavior)
client = Cellcast.enhanced_sms(
  api_key: 'your-api-key',
  default_sender_id: 'YourBrand',
  sandbox_mode: false  # Set to true for testing
)

# Send a message with smart response handling
response = client.quick_send(
  to: '+61400000000',
  message: 'Hello from Cellcast!'
)

# Clean, readable response handling
if response.success?
  puts "Message sent! ID: #{response.message_id}"
  puts "Credits used: #{response.credits_used}"
  puts "Sent to: #{response.to}"
else
  puts "Failed: #{response.api_message}"
end

# Chainable operations for elegant error handling
client.quick_send(to: '+61400000000', message: 'Hello!')
  .on_success { |r| puts "Sent! ID: #{r.message_id}" }
  .on_error { |r| puts "Failed: #{r.api_message}" }
```

### Bulk Operations with Smart Features

```ruby
# Send to multiple recipients with automatic chunking
recipients = ['+61400000000', '+61400000001', '+61400000002']

response = client.broadcast(
  to: recipients,
  message: 'Important announcement!'
)

# Rich information about the broadcast
puts "Success rate: #{response.success_rate}%"
puts "Total sent: #{response.success_number}/#{response.total_numbers}"
puts "Credits used: #{response.credits_used}"

# Handle mixed results
if response.has_failures?
  puts "Some messages failed to send"
else
  puts "All messages sent successfully!"
end

# Iterate through individual messages
response.each_message do |message|
  puts "#{message['to']}: #{message['message_id']}"
end
```

### Account Management with Smart Features

```ruby
# Check account balance with enhanced features
balance = client.balance

puts "SMS Balance: $#{balance.sms_balance}"
puts "MMS Balance: $#{balance.mms_balance}"
puts "Account: #{balance.account_name}"

# Smart balance checking
if balance.low_balance?
  puts "⚠️  Your balance is low!"
end

# Custom thresholds
if client.low_balance?(sms_threshold: 50)
  puts "SMS balance below $50"
end
```

### Message Tracking and Inbound Management

```ruby
# Track message delivery
message_id = response.message_id
final_status = client.track_message_delivery(
  message_id: message_id,
  timeout: 300,      # 5 minutes
  check_interval: 30 # Check every 30 seconds
)

puts "Final status: #{final_status.status}"
puts "Delivered at: #{final_status.delivered_at}" if final_status.delivered?

# Get inbound messages with pagination
inbound = client.get_inbound_messages(page: 1)

puts "Current page: #{inbound.current_page}/#{inbound.total_pages}"
puts "Messages on this page: #{inbound.message_count}"

# Iterate through messages
inbound.each_message do |message|
  puts "From #{message.from}: #{message.body}"
  puts "Received: #{message.received_at}"
  puts "Read: #{message.read? ? 'Yes' : 'No'}"
end

# Get all unread messages across all pages
unread_messages = client.get_all_inbound_messages(unread_only: true)
puts "You have #{unread_messages.length} unread messages"

# Mark all unread messages as read
marked_count = client.mark_all_unread_as_read
puts "Marked #{marked_count} messages as read"
```

### Advanced Features

```ruby
# Send with automatic retry on failure
response = client.quick_send_with_retry(
  to: '+61400000000',
  message: 'Important message',
  max_retries: 5
)

# Large broadcasts with custom chunking
large_list = (1..500).map { |i| "+6140000#{i.to_s.rjust(4, '0')}" }

response = client.broadcast_with_retry(
  to: large_list,
  message: 'Mass notification',
  max_retries: 3
)

# BulkResponseCollection for large broadcasts
puts "Processed #{response.response_count} chunks"
puts "Overall success rate: #{response.success_rate}%"

# Personalized messages
messages = [
  { to: '+61400000000', message: 'Hello John!', sender_id: 'Store' },
  { to: '+61400000001', message: 'Hello Jane!', sender_id: 'Store' },
]

response = client.send_personalized(messages: messages)

# Template-based sending
response = client.send_template(
  template_id: 'welcome_template',
  numbers: [
    { number: '+61400000000', personalization: { name: 'John' } },
    { number: '+61400000001', personalization: { name: 'Jane' } }
  ]
)
```

### Configuration Options

```ruby
# Comprehensive configuration
client = Cellcast.sms(
  api_key: 'your-api-key',
  response_format: :enhanced,        # :enhanced, :raw, or :both
  default_sender_id: 'YourBrand',    # Used when no sender_id specified
  auto_retry_failed: true,           # Automatically retry failed requests
  max_retries: 3,                    # Maximum retry attempts
  chunk_size: 100,                   # Bulk operation chunk size
  low_balance_threshold: 20,         # SMS balance warning threshold
  sandbox_mode: false                # Enable for testing
)

# Quick setups for common scenarios
enhanced_client = Cellcast.enhanced_sms(api_key: 'key', default_sender_id: 'Brand')
raw_client = Cellcast.raw_sms(api_key: 'key')  # For legacy compatibility
```

## Raw Response Mode (Legacy)

For maximum compatibility with existing code, you can use raw response mode:

```ruby
# Create client with raw responses
client = Cellcast.raw_sms(api_key: 'your-api-key')

# Returns raw API responses (Hash objects)
response = client.quick_send(
  to: '+61400000000',
  message: 'Hello!',
  from: 'YourBrand'
)

# Manual response parsing (legacy approach)
if response['meta'] && response['meta']['status'] == 'SUCCESS'
  messages = response.dig('data', 'messages')
  message_id = messages.first['message_id'] if messages&.first
  puts "Message sent! ID: #{message_id}"
  puts "Credits used: #{response.dig('data', 'credits_used')}"
else
  puts "Failed: #{response['msg']}"
end
```

## Error Handling

### Enhanced Error Handling (Recommended)

```ruby
begin
  response = client.quick_send(to: '+61400000000', message: 'Hello!')
rescue Cellcast::SMS::CellcastApiError => e
  case
  when e.insufficient_credit?
    puts "💳 Insufficient credit: #{e.api_message}"
  when e.invalid_number?
    puts "📱 Invalid number format: #{e.api_message}"
  when e.rate_limited?
    puts "⏰ Rate limited. Retry after #{e.suggested_retry_delay} seconds"
  when e.authentication_error?
    puts "🔑 Authentication failed: #{e.api_message}"
  else
    puts "❌ Error: #{e.api_message}"
  end
end

# Automatic retry for retryable errors
begin
  response = client.quick_send_with_retry(
    to: '+61400000000',
    message: 'Important message'
  )
rescue Cellcast::SMS::CellcastApiError => e
  puts "Failed after retries: #{e.api_message}"
end
```

### Legacy Error Handling

```ruby
response = client.quick_send(to: '+61400000000', message: 'Hello!')

case response.dig('meta', 'status')
when 'SUCCESS'
  puts "Message sent successfully"
when 'FAILED'
  puts "Message failed: #{response['msg']}"
end
```

## Full API Reference

### All Available Methods

```ruby
# SMS Operations
client.quick_send(to:, message:, from: nil)
client.quick_send_with_retry(to:, message:, from: nil, max_retries: nil)
client.broadcast(to:, message:, from: nil, chunk_size: nil)
client.broadcast_with_retry(to:, message:, from: nil, max_retries: nil)
client.send_personalized(messages:, chunk_size: nil)
client.send_to_nz(to:, message:, from: nil)
client.send_template(template_id:, numbers:, from: nil)

# Message Management
client.get_message_status(message_id:)
client.track_message_delivery(message_id:, timeout: 300, check_interval: 30)
client.delivery_stats(message_ids)

# Inbound Messages
client.get_inbound_messages(page: 1)
client.get_all_inbound_messages(limit: nil, unread_only: false)
client.inbound_message_stats(pages: 1)
client.mark_read(message_id:)
client.mark_all_read(before: nil)
client.mark_all_unread_as_read(before: nil)

# Account Operations
client.balance
client.low_balance?(sms_threshold: nil, mms_threshold: 5)
client.get_templates
client.find_template(identifier)
client.get_optouts

# Registration
client.register_alpha_id(alpha_id:, purpose:, business_registration: nil, contact_info: nil)
```

### Response Object Methods

#### SendSmsResponse
```ruby
response.success?              # Boolean: API call successful
response.error?                # Boolean: API call failed  
response.message_id            # String: Message ID
response.credits_used          # Integer: Credits consumed
response.to                    # String: Recipient number
response.from                  # String: Sender ID used
response.message_text          # String: Message content
response.all_successful?       # Boolean: All messages sent
response.api_message           # String: API response message
response.raw_response          # Hash: Full API response
```

#### BulkSmsResponse
```ruby
response.success_rate          # Float: Success percentage
response.total_numbers         # Integer: Total recipients
response.success_number        # Integer: Successful sends
response.failed_number         # Integer: Failed sends
response.credits_used          # Integer: Credits consumed
response.messages              # Array: Message details
response.all_successful?       # Boolean: All messages sent
response.has_failures?         # Boolean: Any failures occurred
response.each_message { |msg| ... }  # Iterate messages
```

#### AccountBalanceResponse
```ruby
balance.sms_balance           # String: SMS balance
balance.mms_balance           # String: MMS balance
balance.account_name          # String: Account name
balance.low_sms_balance?(threshold)   # Boolean: SMS balance low
balance.low_mms_balance?(threshold)   # Boolean: MMS balance low
balance.low_balance?(sms_thresh, mms_thresh)  # Boolean: Any balance low
balance.total_balance         # Float: Combined balance
```

#### InboundMessagesResponse
```ruby
inbound.messages              # Array<InboundMessage>: Message objects
inbound.current_page          # Integer: Current page number
inbound.total_pages          # Integer: Total pages available
inbound.has_more_pages?      # Boolean: More pages available
inbound.message_count        # Integer: Messages on current page
inbound.unread_messages      # Array: Unread messages only
inbound.each_message { |msg| ... }   # Iterate messages
```

#### InboundMessage
```ruby
message.from                 # String: Sender number
message.body                 # String: Message content
message.received_at          # Time: When received
message.message_id           # String: Message ID
message.read?                # Boolean: Has been read
message.unread?              # Boolean: Not yet read
```

### Chainable Operations

All enhanced response objects support chainable operations:

```ruby
client.quick_send(to: number, message: text)
  .on_success { |response| log_success(response.message_id) }
  .on_error { |response| log_error(response.api_message) }

client.broadcast(to: numbers, message: text)
  .on_success { |response| puts "Sent to #{response.success_number} recipients" }
  .on_error { |response| puts "Broadcast failed: #{response.api_message}" }
```

## Configuration

### Environment Variables

You can set defaults using environment variables:

```bash
export CELLCAST_API_KEY="your-api-key"
export CELLCAST_DEFAULT_SENDER_ID="YourBrand"
export CELLCAST_SANDBOX_MODE="true"  # For testing
```

```ruby
# Use environment variables
client = Cellcast.enhanced_sms(
  api_key: ENV['CELLCAST_API_KEY'],
  default_sender_id: ENV['CELLCAST_DEFAULT_SENDER_ID'],
  sandbox_mode: ENV['CELLCAST_SANDBOX_MODE'] == 'true'
)
```

### Advanced Configuration

```ruby
config = Cellcast.configure do |c|
  c.response_format = :enhanced
  c.open_timeout = 30
  c.read_timeout = 60
  c.auto_retry_failed = true
  c.max_retries = 3
  c.retry_delay = 2  # Base delay for exponential backoff
  c.chunk_size = 100
  c.low_balance_threshold = 10
  c.sandbox_mode = false
end

client = Cellcast.sms(api_key: 'your-key', config: config)
```

## Testing

### Sandbox Mode

The gem includes a comprehensive sandbox mode for testing without making real API calls:

```ruby
# Enable sandbox mode
client = Cellcast.enhanced_sms(
  api_key: 'test-key',
  sandbox_mode: true
)

# Special test numbers trigger different behaviors
client.quick_send(to: '+15550000000', message: 'Test')  # Always succeeds
client.quick_send(to: '+15550000001', message: 'Test')  # Always fails
client.quick_send(to: '+15550000002', message: 'Test')  # Rate limited
client.quick_send(to: '+15550000003', message: 'Test')  # Invalid number
client.quick_send(to: '+15550000004', message: 'Test')  # Insufficient credits
```

### Running Tests

```bash
# Run all tests
bundle exec rake test

# Run specific test files
ruby -I lib test/test_enhanced_convenience.rb
ruby -I lib test/test_raw_response_format.rb
ruby -I lib test/test_enhanced_error_handling.rb
ruby -I lib test/test_helper_classes.rb
```

## Migration Guide

### From Raw to Enhanced Responses

If you're upgrading from raw response format to enhanced format:

```ruby
# Before (raw responses)
if response['meta']['status'] == 'SUCCESS'
  message_id = response.dig('data', 'messages', 0, 'message_id')
  credits = response.dig('data', 'credits_used')
  puts "Sent! ID: #{message_id}, Credits: #{credits}"
end

# After (enhanced responses)
if response.success?
  puts "Sent! ID: #{response.message_id}, Credits: #{response.credits_used}"
end

# Enhanced responses still support hash access for compatibility
message_id = response['data']['messages'][0]['message_id']  # Still works
message_id = response.dig('data', 'messages', 0, 'message_id')  # Still works
```

### Gradual Migration

You can use `:both` response format to migrate gradually:

```ruby
client = Cellcast.sms(
  api_key: 'your-key',
  response_format: :both  # Enhanced objects with full raw access
)

response = client.quick_send(to: number, message: text)

# Use enhanced methods
puts response.success?
puts response.message_id

# Still access raw data when needed
puts response.raw_response['data']['messages']
puts response['meta']['status']  # Hash access still works
```

## Official API Documentation

This gem strictly aligns with the [official Cellcast API documentation](https://cellcast.com.au/api/documentation/). All endpoints, request formats, and response structures match the official specification.

### Supported Endpoints

- `send-sms` - Send single SMS
- `bulk-send-sms` - Send bulk SMS  
- `get-sms` - Get message details
- `get-responses` - Get inbound messages
- `send-sms-nz` - Send SMS to New Zealand
- `send-sms-template` - Send template SMS
- `inbound-read` - Mark message as read
- `inbound-read-bulk` - Mark multiple messages as read
- `register-alpha-id` - Register business name
- `account` - Get account balance
- `get-template` - Get SMS templates
- `get-optout` - Get opt-out list

## Requirements

- Ruby 3.2 or higher
- No external dependencies (uses only Ruby standard library)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/timburgan/cellcast-sms.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Disclaimer

This is an unofficial gem. I am not affiliated with Cellcast. Use at your own risk and always test thoroughly before production use.
