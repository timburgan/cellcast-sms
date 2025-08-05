# Cellcast SMS

A Ruby gem for interacting with the Cellcast API SMS endpoints. This gem provides a clean, simple interface for sending SMS messages, managing sender IDs, and configuring webhooks.

## Features

- Send individual and bulk SMS messages
- Manage sender IDs (business names and custom numbers)
- **Handle incoming messages and replies** - New!
- Configure and manage webhooks for real-time notifications
- Token verification and usage tracking
- Comprehensive error handling
- Minimal dependencies (uses only Ruby standard library)
- Ruby 3.3+ support

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cellcast-sms'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install cellcast-sms

## Usage

### Basic Setup

```ruby
require 'cellcast'

# Create a client
client = Cellcast.sms(api_key: 'your-api-key')

# Or with custom base URL
client = Cellcast.sms(
  api_key: 'your-api-key',
  base_url: 'https://api.cellcast.com'
)
```

### Quick Example

```ruby
# Send an SMS
response = client.sms.send_message(
  to: '+1234567890',
  message: 'Hello from Cellcast!',
  sender_id: 'YourBrand'
)

# Check for incoming messages and replies
incoming = client.incoming.list_incoming(unread_only: true)
incoming.each do |message|
  puts "Received from #{message['from']}: #{message['message']}"
end

# Configure webhook for real-time notifications
client.webhook.configure_webhook(
  url: 'https://yourapp.com/webhooks/cellcast',
  events: ['sms.sent', 'sms.delivered', 'sms.received', 'sms.reply']
)
```

### Sending SMS Messages

#### Send a Single Message

```ruby
response = client.sms.send_message(
  to: '+1234567890',
  message: 'Hello from Cellcast!',
  sender_id: 'YourBrand'  # optional
)

puts response['message_id']
```

#### Send Bulk Messages

```ruby
messages = [
  { to: '+1234567890', message: 'Hello User 1!' },
  { to: '+0987654321', message: 'Hello User 2!', sender_id: 'CustomID' }
]

response = client.sms.send_bulk(messages: messages)
puts response['batch_id']
```

#### Check Message Status

```ruby
status = client.sms.get_status(message_id: 'msg_123456')
puts status['status']  # 'sent', 'delivered', 'failed', etc.

# Get detailed delivery report
report = client.sms.get_delivery_report(message_id: 'msg_123456')
```

#### List Sent Messages

```ruby
messages = client.sms.list_messages(
  limit: 50,
  offset: 0,
  date_from: '2024-01-01',
  date_to: '2024-01-31'
)
```

### Handling Incoming Messages & Replies

#### List Incoming Messages

```ruby
# Get all incoming messages
incoming = client.incoming.list_incoming(
  limit: 50,
  offset: 0,
  unread_only: true
)

# Filter by date range and sender ID  
incoming = client.incoming.list_incoming(
  date_from: '2024-01-01',
  date_to: '2024-01-31',
  sender_id: 'YourBrand'
)
```

#### Get Specific Incoming Message

```ruby
message = client.incoming.get_incoming_message(message_id: 'incoming_123456')
puts message['from']  # Sender's phone number
puts message['message']  # Message content
puts message['received_at']  # Timestamp
```

#### Mark Messages as Read

```ruby
# Mark single message as read
client.incoming.mark_as_read(message_ids: ['incoming_123456'])

# Mark multiple messages as read
client.incoming.mark_as_read(
  message_ids: ['incoming_123456', 'incoming_789012']
)
```

#### Get Replies to Sent Messages

```ruby
# Get all replies to a specific sent message
replies = client.incoming.get_replies(
  original_message_id: 'msg_123456',
  limit: 10
)

replies.each do |reply|
  puts "Reply from #{reply['from']}: #{reply['message']}"
end
```

### Managing Sender IDs

#### Register Business Name

```ruby
response = client.sender_id.register_business_name(
  business_name: 'Your Company',
  business_registration: 'REG123456',
  contact_info: {
    email: 'contact@yourcompany.com',
    phone: '+1234567890'
  }
)
```

#### Register Custom Number

```ruby
response = client.sender_id.register_custom_number(
  phone_number: '+1234567890',
  purpose: 'Customer notifications'
)
```

#### Verify Custom Number

```ruby
response = client.sender_id.verify_custom_number(
  phone_number: '+1234567890',
  verification_code: '123456'
)
```

#### List Sender IDs

```ruby
sender_ids = client.sender_id.list_sender_ids(
  type: 'business_name',  # or 'custom_number'
  status: 'approved'
)
```

### Webhook Management

#### Configure Webhook

```ruby
response = client.webhook.configure_webhook(
  url: 'https://yourapp.com/webhooks/cellcast',
  events: [
    'sms.sent', 'sms.delivered', 'sms.failed',
    'sms.received', 'sms.reply'
  ],
  secret: 'your-webhook-secret'  # optional
)
```

#### Test Webhook

```ruby
response = client.webhook.test_webhook(event_type: 'test')
```

#### Get Webhook Logs

```ruby
logs = client.webhook.get_delivery_logs(limit: 100, offset: 0)
```

### Token Management

#### Verify Token

```ruby
token_info = client.token.verify_token
puts token_info['valid']
```

#### Get Usage Statistics

```ruby
stats = client.token.get_usage_stats(period: 'monthly')
puts stats['messages_sent']
```

## Error Handling

The gem provides specific error classes for different types of failures:

```ruby
begin
  client.sms.send_message(to: '+1234567890', message: 'Hello!')
rescue Cellcast::SMS::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
rescue Cellcast::SMS::RateLimitError => e
  puts "Rate limit exceeded: #{e.message}"
  puts "Status code: #{e.status_code}"
rescue Cellcast::SMS::ValidationError => e
  puts "Validation error: #{e.message}"
rescue Cellcast::SMS::APIError => e
  puts "API error: #{e.message}"
  puts "Status code: #{e.status_code}"
  puts "Response: #{e.response_body}"
end
```

## Available Error Classes

- `Cellcast::SMS::Error` - Base error class
- `Cellcast::SMS::AuthenticationError` - Invalid API key or unauthorized access
- `Cellcast::SMS::ValidationError` - Invalid parameters or data
- `Cellcast::SMS::APIError` - General API errors (4xx, 5xx responses)
- `Cellcast::SMS::RateLimitError` - Rate limit exceeded (429 responses)
- `Cellcast::SMS::ServerError` - Server errors (5xx responses)

## Supported API Endpoints

### SMS Endpoints
- `POST /sms/send` - Send single SMS
- `POST /sms/bulk` - Send bulk SMS
- `GET /sms/status/{id}` - Get message status
- `GET /sms/delivery/{id}` - Get delivery report
- `GET /sms/messages` - List sent messages

### Incoming SMS Endpoints
- `GET /sms/incoming` - List incoming messages and replies
- `GET /sms/incoming/{id}` - Get specific incoming message
- `POST /sms/mark-read` - Mark messages as read
- `GET /sms/replies/{id}` - Get replies to a sent message

### Sender ID Endpoints
- `POST /sender-id/business-name` - Register business name
- `GET /sender-id/business-name/{id}` - Get business name status
- `POST /sender-id/custom-number` - Register custom number
- `POST /sender-id/verify-custom-number` - Verify custom number
- `GET /sender-id/custom-number/{number}` - Get custom number status
- `GET /sender-id/list` - List sender IDs

### Token Endpoints
- `GET /auth/verify-token` - Verify API token
- `GET /auth/token-info` - Get token information
- `POST /auth/refresh-token` - Refresh token
- `GET /auth/usage-stats` - Get usage statistics

### Webhook Endpoints
- `POST /webhooks/configure` - Configure webhook
- `GET /webhooks/config` - Get webhook configuration
- `POST /webhooks/test` - Test webhook
- `DELETE /webhooks/config` - Delete webhook
- `GET /webhooks/logs` - Get delivery logs
- `POST /webhooks/retry` - Retry failed delivery

## Development Philosophy

This gem follows Sandi Metz rules for object-oriented design:

1. Classes should be no longer than 100 lines
2. Methods should be no longer than 5 lines
3. Methods should accept no more than 4 parameters
4. Controllers should only instantiate one object

## Requirements

- Ruby 3.3.0 or higher
- No external dependencies (uses only Ruby standard library)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/timburgan/cellcast-sms.

## License

The gem is available as open source under the terms of the MIT License.