# Cellcast SMS

> **Note**: This is an unofficial gem that wraps the [official Cellcast API](https://developer.cellcast.com). I built this for me own use to make my life easier.

A Ruby gem for the Cellcast API focused on SMS sending, account management, and sender ID registration. Simple, reliable SMS delivery with a developer-friendly interface.

## Features

- **Send SMS**: Individual messages and bulk broadcasts
- **Account Management**: Check balance and usage reports
- **Sender ID Management**: Register business names and custom numbers
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

# Send to multiple recipients
broadcast = client.broadcast(
  to: ['+1234567890', '+0987654321'],
  message: 'Important announcement!'
)

puts "Sent to #{broadcast.successful_count} recipients"
puts "Total cost: $#{broadcast.total_cost}"

# Check account balance
balance = client.balance
puts "Current balance: $#{balance.data['balance']}"

# Get usage statistics
usage = client.usage_report
puts "Messages sent this month: #{usage.data['messages_sent']}"

# Register a business name for sender ID
client.sender_id.register_business_name(
  business_name: 'Your Company Ltd',
  business_registration: 'REG123456',
  contact_info: {
    email: 'contact@yourcompany.com',
    phone: '+1234567890'
  }
)
```

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
  puts "Attempted URL: #{e.requested_url}"
rescue Cellcast::SMS::NetworkError => e
  puts "Network error: #{e.message}"
  # Gem automatically retried 3 times with exponential backoff
rescue Cellcast::SMS::APIError => e
  puts "API error: #{e.message}"
  puts "Attempted URL: #{e.requested_url}"
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

# Cancel a scheduled message
client.cancel_message(message_id: 'msg_123456789')

# Account operations
balance = client.account.get_account_balance
usage = client.account.get_usage_report

# Sender ID management
client.sender_id.register_business_name(
  business_name: 'Your Company Ltd',
  business_registration: 'REG123456',
  contact_info: { email: 'contact@yourcompany.com', phone: '+1234567890' }
)

client.sender_id.register_custom_number(
  phone_number: '+1234567890',
  purpose: 'Customer notifications'
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