# Cellcast SMS

> **Note**: This is an unofficial gem that wraps the [official Cellcast API](https://developer.cellcast.com). I built this for me own use to make my life easier.

A Ruby gem for the Cellcast API with complete bidirectional SMS support. Send messages, receive replies, and manage conversations with a simple, developer-friendly interface.

## Features

- **Send SMS**: Individual messages and bulk broadcasts
- **Receive SMS**: Incoming messages and replies with real-time webhooks
- **Zero Configuration**: Sensible defaults with automatic retries and error handling
- **Developer Friendly**: Structured response objects and helpful error messages  
- **Ruby 3.3+**: Uses only Ruby standard library, no external dependencies

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

### Basic Usage

```ruby
require 'cellcast'

# Create client with your API key
client = Cellcast.sms(api_key: 'your-api-key')

# Send a message
response = client.quick_send(
  to: '+1234567890',
  message: 'Hello from Cellcast!',
  from: 'YourBrand'
)

puts "Message sent! ID: #{response.message_id}" if response.success?

# Check delivery status
if client.delivered?(message_id: response.message_id)
  puts "Message delivered successfully!"
end

# Send to multiple recipients
broadcast = client.broadcast(
  to: ['+1234567890', '+0987654321'],
  message: 'Important announcement!'
)

puts "Sent to #{broadcast.successful_count} recipients"
puts "Total cost: $#{broadcast.total_cost}"

# Handle incoming messages and replies
unread = client.unread_messages
unread.items.each do |message|
  puts "From #{message.from}: #{message.message}"
  
  if message.is_reply?
    puts "This is a reply to message: #{message.original_message_id}"
  end
end

# Set up webhook for real-time notifications
client.setup_webhook(url: 'https://yourapp.com/webhooks')
```

### Sandbox Mode for Testing

The gem includes a built-in sandbox mode perfect for testing your integration without making live API calls or incurring costs:

```ruby
# Enable sandbox mode
config = Cellcast::SMS::Configuration.new
config.sandbox_mode = true

client = Cellcast.sms(api_key: 'test-key', config: config)

# All methods work the same, but no live calls are made
response = client.quick_send(to: '+1234567890', message: 'Test message')
puts response.success? # => true (mock response)
```

**Special Test Numbers** (inspired by Stripe's test cards):

```ruby
# These numbers trigger specific behaviors in sandbox mode:
'+15550000000' # → Always succeeds
'+15550000001' # → Always fails  
'+15550000002' # → Rate limited (throws RateLimitError)
'+15550000003' # → Invalid number (throws ValidationError)
'+15550000004' # → Insufficient credits (throws APIError)
```

Perfect for testing error handling in your application:

```ruby
# Test error handling
begin
  client.quick_send(to: '+15550000002', message: 'Test')
rescue Cellcast::SMS::RateLimitError => e
  puts "Handle rate limiting: #{e.retry_after} seconds"
end
```

See `examples/sandbox_mode.rb` for a complete sandbox demonstration.

## Error Handling

The gem includes automatic retries and helpful error messages:

```ruby
begin
  response = client.quick_send(to: '+1234567890', message: 'Hello!')
rescue Cellcast::SMS::ValidationError => e
  puts "Validation error: #{e.message}"
  # Example: "Phone number must be in international format (e.g., +1234567890)"
rescue Cellcast::SMS::RateLimitError => e
  puts "Rate limited. Retry after: #{e.retry_after} seconds"
rescue Cellcast::SMS::NetworkError => e
  puts "Network error: #{e.message}"
  # Gem automatically retried 3 times with exponential backoff
end
```

## Advanced Usage

For complete API documentation, advanced examples, architecture details, and sequence diagrams, see the [**Developer Guide**](DEVELOPER.md).

The gem provides two levels of access:

**Convenience Methods** (shown above) - Perfect for common use cases  
**Full API Access** - Complete control over all parameters:

```ruby
# Direct API access for advanced customization
response = client.sms.send_message(
  to: '+1234567890',
  message: 'Hello!',
  sender_id: 'YourBrand'
)

incoming = client.incoming.list_incoming(unread_only: true)

client.webhook.configure_webhook(
  url: 'https://yourapp.com/webhooks',
  events: ['sms.sent', 'sms.delivered', 'sms.received', 'sms.reply']
)
```

## Documentation

- **[Developer Guide](DEVELOPER.md)** - Complete documentation with examples, API reference, and architecture diagrams
- **[Changelog](CHANGELOG.md)** - Version history and changes
- Official API documentation is at https://developer.cellcast.com

## Requirements

- Ruby 3.3.0 or higher

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/timburgan/cellcast-sms.

## License

Available under the [MIT License](LICENSE.txt).