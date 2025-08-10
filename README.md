# Cellcast SMS

> **Note**: This is an unofficial gem that wraps the [official Cellcast API](https://cellcast.com.au/api/documentation/). I built this for my own use to make my life easier.

A Ruby gem for the Cellcast API focused on SMS sending and account management. Simple, reliable SMS delivery that returns raw API responses directly from the official Cellcast API.

## Features

- **Send SMS**: Individual messages to single recipients using official `send-sms` endpoint
- **Bulk SMS**: Send to multiple recipients using official `bulk-send-sms` endpoint  
- **Account Management**: Check balance using official `account` endpoint
- **Message Tracking**: Get message details using official `get-sms` endpoint
- **Inbound Messages**: Retrieve incoming SMS using official `get-responses` endpoint
- **New Zealand SMS**: Dedicated `send-sms-nz` endpoint for NZ numbers
- **Template Messages**: Send SMS using predefined templates via `send-sms-template` endpoint
- **Alpha ID Registration**: Register business names using `register-alpha-id` endpoint
- **Inbound Management**: Mark messages as read using `inbound-read` and `inbound-read-bulk` endpoints
- **Opt-out Management**: Get opt-out lists using `get-optout` endpoint
- **Template Management**: Get available templates using `get-template` endpoint
- **Zero Configuration**: Sensible defaults with automatic retries and error handling
- **Official API Responses**: Returns raw API responses with official Cellcast structure
- **Ruby 3.2+**: Uses only Ruby standard library, no external dependencies

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

# Send a message (uses official send-sms endpoint)
response = client.quick_send(
  to: '+61400000000',
  message: 'Hello from Cellcast!',
  from: 'YourBrand'
)

# Official API response structure
if response['meta'] && response['meta']['status'] == 'SUCCESS'
  messages = response.dig('data', 'messages')
  message_id = messages.first['message_id'] if messages&.first
  puts "Message sent! ID: #{message_id}"
  puts "Credits used: #{response.dig('data', 'credits_used')}"
else
  puts "Failed: #{response['msg']}"
end

# Send to multiple recipients (uses official bulk-send-sms endpoint)
broadcast = client.broadcast(
  to: ['+61400000000', '+61400000001'],
  message: 'Important announcement!'
)

puts "Sent to #{broadcast.dig('data', 'success_number')} recipients"
puts "Total numbers: #{broadcast.dig('data', 'total_numbers')}"

# Check account balance (uses official account endpoint)
balance = client.balance
puts "SMS Balance: $#{balance.dig('data', 'sms_balance')}"
puts "MMS Balance: $#{balance.dig('data', 'mms_balance')}"

# Get message details (uses official get-sms endpoint)
message_status = client.get_message_status(message_id: 'your-message-id')
if message_status['meta']['status'] == 'SUCCESS'
  message_data = message_status['data'].first
  puts "Message status: #{message_data['status']}"
  puts "Sent time: #{message_data['sent_time']}"
end

# Register a business name for sender ID (uses official register-alpha-id endpoint)
registration_response = client.register_alpha_id(
  alpha_id: 'YourBrand',
  purpose: 'Customer notifications'
)
puts "Registration: #{registration_response['msg']}"
```

## Error Handling

The gem includes automatic retries and helpful error messages. The official Cellcast API returns error responses in the following format:

```ruby
begin
  response = client.quick_send(to: '+61400000000', message: 'Hello!')
  
  # Check for API-level errors in response
  if response['meta']['status'] != 'SUCCESS'
    puts "API Error: #{response['msg']}"
    puts "Error Code: #{response['meta']['code']}"
  end
  
rescue Cellcast::SMS::ValidationError => e
  puts "Validation error: #{e.message}"
  # Example: "Phone number must be in international format (e.g., +61400000000)"
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

### Official API Error Response Format

```json
{
  "meta": {
    "code": 400,
    "status": "FIELD_INVALID"
  },
  "msg": "You can send the maximum message length of 918 characters, or send a message length of 402 characters for the Unicode character set.",
  "data": []
}
```

### Common API Error Codes

- **AUTH_FAILED_NO_DATA** (401): APPKEY not provided
- **AUTH_FAILED** (401): Invalid APPKEY or unregistered user  
- **FIELD_EMPTY** (400): Required field is empty
- **FIELD_INVALID** (400): Field contains invalid data
- **RECIPIENTS_ERROR** (400): Invalid recipient format

## Advanced Usage

The gem provides two levels of access:

**Convenience Methods** (shown above) - Perfect for common use cases  
**Full API Access** - Complete control over all parameters using official API endpoints:

```ruby
# Direct API access for advanced customization
response = client.sms.send_message(
  to: '+61400000000',
  message: 'Hello!',
  sender_id: 'YourBrand'
)

# All methods now return raw API responses as Hash objects
puts "Status: #{response['meta']['status']}"
puts "Message: #{response['msg']}"
puts "Message ID: #{response.dig('data', 'messages', 0, 'message_id')}"

# Get message details (official get-sms endpoint)
message_details = client.sms.get_message(message_id: 'msg_123456789')
puts "Message status: #{message_details.dig('data', 0, 'status')}"

# Get inbound messages (official get-responses endpoint)
inbound = client.sms.get_responses(page: 1, type: 'sms')
responses = inbound.dig('data', 'responses') || []
puts "Received #{responses.length} inbound messages"

# Send to New Zealand numbers (official send-sms-nz endpoint)
nz_response = client.sms.send_message_nz(
  to: '+64211234567',
  message: 'Hello New Zealand!',
  sender_id: 'YourBrand'
)

# Send using templates (official send-sms-template endpoint)
template_response = client.sms.send_message_template(
  template_id: 'template_123',
  numbers: [
    { number: '+61400000000', fname: 'John', lname: 'Doe' }
  ],
  sender_id: 'YourBrand'
)

# Account operations (official account endpoint)
balance = client.account.get_account_balance
puts "SMS Balance: $#{balance.dig('data', 'sms_balance')}"
puts "MMS Balance: $#{balance.dig('data', 'mms_balance')}"

# Get available templates (official get-template endpoint)
templates = client.account.get_templates
puts "Available templates: #{templates.dig('data')&.length || 0}"

# Get opt-out list (official get-optout endpoint)
optouts = client.account.get_optout_list
puts "Opt-out list: #{optouts.dig('data')&.length || 0}"

# Alpha ID registration (official register-alpha-id endpoint)
registration = client.sender_id.register_alpha_id(
  alpha_id: 'YourBrand',
  purpose: 'Customer notifications'
)
puts "Registration: #{registration['msg']}"

# Mark inbound messages as read (official inbound-read endpoint)
client.sms.mark_inbound_read(message_id: 'inbound_msg_123')

# Mark all inbound messages as read (official inbound-read-bulk endpoint)
client.sms.mark_inbound_read_bulk(timestamp: '2024-01-01 00:00:00')
```

## Developer Guide

### Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [API Flow Diagrams](#api-flow-diagrams)
3. [Advanced Usage Examples](#advanced-usage-examples)
4. [Complete API Reference](#complete-api-reference)
5. [Error Handling & Retry Logic](#error-handling--retry-logic)
6. [Configuration Options](#configuration-options)
7. [Response Objects](#response-objects)
8. [Testing & Development](#testing--development)
9. [Security Considerations](#security-considerations)

### Architecture Overview

The Cellcast SMS gem follows a layered architecture designed for simplicity and extensibility:

```
┌─────────────────────────────────────────┐
│           Convenience Layer             │
│  (quick_send, broadcast, delivered?)    │
├─────────────────────────────────────────┤
│            API Modules Layer            │
│   (sms, incoming, sender_id, webhook)   │
├─────────────────────────────────────────┤
│           HTTP Client Layer             │
│        (request/response handling)      │
├─────────────────────────────────────────┤
│           Transport Layer               │
│         (Net::HTTP, SSL, retries)       │
└─────────────────────────────────────────┘
```

#### Design Principles

1. **Zero Configuration Complexity**: Sensible defaults eliminate configuration overhead
2. **Developer Experience First**: Common operations require minimal code
3. **Failure Resilience**: Automatic retries with exponential backoff
4. **Clean Separation**: Clear boundaries between convenience and full API access

### API Flow Diagrams

#### SMS Sending Flow

```mermaid
sequenceDiagram
    participant App as Your Application
    participant Client as Cellcast Client
    participant Retry as Retry Handler
    participant API as Cellcast API

    App->>Client: quick_send(to, message, from)
    Client->>Client: Validate parameters
    Client->>Retry: execute_with_retry()
    
    loop Retry Logic (max 3 attempts)
        Retry->>API: POST /api/v1/gateway
        
        alt Success (200/201)
            API-->>Retry: Success response
            Retry-->>Client: Return response
            Client->>Client: Create SMSResponse object
            Client-->>App: Return structured response
        
        else Rate Limit (429)
            API-->>Retry: 429 + Retry-After header
            Retry->>Retry: Wait (Retry-After or exponential backoff)
            Note over Retry: Retry attempt
        
        else Server Error (5xx)
            API-->>Retry: 5xx error
            Retry->>Retry: Wait (exponential backoff: 1s, 2s, 4s)
            Note over Retry: Retry attempt
        
        else Client Error (4xx)
            API-->>Retry: 4xx error
            Retry-->>Client: Raise specific error
            Client-->>App: Raise ValidationError/AuthenticationError
        end
    end
    
    alt Max retries exceeded
        Retry-->>Client: Raise NetworkError/ServerError
        Client-->>App: Raise error with retry context
    end
```

#### Account Balance Flow

```mermaid
sequenceDiagram
    participant App as Your Application
    participant Client as Cellcast Client
    participant API as Cellcast API

    Note over App,API: Check Account Balance
    
    App->>Client: balance()
    Client->>API: GET /api/v1/apiClient/account
    API-->>Client: Account balance data
    Client->>Client: Create Response object
    Client-->>App: Return balance information
    
    Note over App,API: Get Usage Statistics
    
    App->>Client: usage_report()
    Client->>API: GET /api/v2/report/message/quick-api-credit-usage
    API-->>Client: Usage statistics
    Client->>Client: Create Response object
    Client-->>App: Return usage data
```

#### Error Recovery Flow

```mermaid
sequenceDiagram
    participant App as Your Application
    participant Client as Cellcast Client
    participant Retry as Retry Handler
    participant API as Cellcast API

    App->>Client: quick_send(...)
    Client->>Retry: execute_with_retry()
    
    Retry->>API: Attempt 1
    API-->>Retry: Network timeout
    
    Retry->>Retry: Wait 1 second
    Retry->>API: Attempt 2
    API-->>Retry: 500 Server Error
    
    Retry->>Retry: Wait 2 seconds
    Retry->>API: Attempt 3
    API-->>Retry: 200 Success
    
    Retry-->>Client: Success response
    Client-->>App: Return result
    
    Note over Retry: Exponential backoff: 1s → 2s → 4s (max 32s)
```

### Advanced Usage Examples

#### Complete SMS Workflow

```ruby
require 'cellcast'

# Initialize client
client = Cellcast.sms(api_key: ENV['CELLCAST_API_KEY'])

begin
  # Send initial message
  response = client.quick_send(
    to: '+1234567890',
    message: 'Welcome! Your account has been created.',
    from: 'YourBrand'
  )
  
  if response['status']
    message_id = response.dig('data', 'queueResponse', 0, 'MessageId')
    puts "Message sent: #{message_id}"
  end
  
  # Check account balance after sending
  balance = client.balance
  puts "Remaining balance: $#{balance.dig('data', 'balance') || 'Unknown'}"
  
  # Get usage statistics
  usage = client.usage_report
  puts "Messages sent this month: #{usage.dig('data', 'messages_sent') || 'Unknown'}"

rescue Cellcast::SMS::ValidationError => e
  puts "Validation error: #{e.message}"
rescue Cellcast::SMS::RateLimitError => e
  puts "Rate limited. Retry after: #{e.retry_after} seconds"
  puts "Attempted URL: #{e.requested_url}"
rescue Cellcast::SMS::NetworkError => e
  puts "Network error. Message may have been sent. Check account balance."
  puts "Attempted URL: #{e.requested_url}"
rescue Cellcast::SMS::APIError => e
  puts "API error: #{e.message}"
  puts "Attempted URL: #{e.requested_url}"
end
```

#### Bulk Messaging with Error Handling

```ruby
# Prepare recipient list
recipients = [
  '+1234567890',
  '+1987654321',
  '+1555000111'
]

# Send broadcast with error tracking
begin
  broadcast_response = client.broadcast(
    to: recipients,
    message: 'Important system maintenance scheduled tonight.',
    from: 'TechOps'
  )
  
  puts "Broadcast Results:"
  puts "  Successful: #{broadcast_response.dig('data', 'totalValidContact') || 0}"
  puts "  Failed: #{broadcast_response.dig('data', 'totalInvalidContact') || 0}"
  
  # Check remaining balance after bulk send
  balance = client.balance
  puts "Remaining balance: $#{balance.dig('data', 'balance') || 'Unknown'}"
  
rescue Cellcast::SMS::APIError => e
  puts "API Error: #{e.message}"
  puts "Status: #{e.status_code}"
  puts "Attempted URL: #{e.requested_url}"
  puts "Response: #{e.response_body}"
end
```

#### Sender ID Management Example

```ruby
# Register a business name for sender ID
begin
  business_response = client.sender_id.register_business_name(
    business_name: 'Your Company Ltd',
    business_registration: 'REG123456',
    contact_info: {
      email: 'contact@yourcompany.com',
      phone: '+1234567890',
      address: '123 Business St, City'
    }
  )
  
  puts "Business name registration: #{business_response['status']}"
  puts "Application ID: #{business_response['application_id']}"
  
rescue Cellcast::SMS::APIError => e
  puts "Registration failed: #{e.message}"
  puts "Attempted URL: #{e.requested_url}"
end

# Register a custom phone number
begin
  number_response = client.sender_id.register_custom_number(
    phone_number: '+1234567890',
    purpose: 'Customer notifications and support'
  )
  
  puts "Custom number registration: #{number_response['status']}"
  puts "Verification required: #{number_response['verification_required']}"
  
  # If verification is required, verify with code
  if number_response['verification_required']
    verification_response = client.sender_id.verify_custom_number(
      phone_number: '+1234567890',
      verification_code: '123456'  # Code received via SMS
    )
    
    puts "Verification result: #{verification_response['verified']}"
  end
  
rescue Cellcast::SMS::APIError => e
  puts "Number registration failed: #{e.message}"
  puts "Attempted URL: #{e.requested_url}"
end
```

### Complete API Reference

### Complete API Reference

All methods return raw responses in the official Cellcast API format:

```json
{
  "meta": {
    "code": 200,
    "status": "SUCCESS"
  },
  "msg": "Queued",
  "data": {
    "messages": [...],
    "total_numbers": 1,
    "success_number": 1,
    "credits_used": 1
  }
}
```

#### SMS Module (`client.sms`)

##### Send Single Message
**Official Endpoint:** `POST https://cellcast.com.au/api/v3/send-sms`

```ruby
response = client.sms.send_message(
  to: '+61400000000',           # Required: recipient phone number
  message: 'Hello World!',      # Required: message content (1-918 chars)
  sender_id: 'YourBrand'        # Optional: sender ID
)
```

**Request Format (Official API):**
```json
{
  "sms_text": "Hello World!",
  "numbers": ["+61400000000"]
}
```

**Response Format:**
```json
{
  "meta": {
    "code": 200,
    "status": "SUCCESS"
  },
  "msg": "Queued",
  "data": {
    "messages": [
      {
        "message_id": "6EF87246-52D3-74FB-C319-NNNNNNNNNN",
        "from": "YourBrand",
        "to": "+61400000000",
        "body": "Hello World!",
        "date": "2024-01-15 14:02:29",
        "custom_string": "",
        "direction": "out"
      }
    ],
    "total_numbers": 1,
    "success_number": 1,
    "credits_used": 1
  }
}
```

##### Send Bulk Messages
**Official Endpoint:** `POST https://cellcast.com.au/api/v3/bulk-send-sms`

```ruby
response = client.sms.send_bulk(
  messages: [
    { to: '+61400000000', message: 'Hello User 1!' },
    { to: '+61400000001', message: 'Hello User 2!', sender_id: 'Custom' }
  ]
)
```

##### Get Message Details
**Official Endpoint:** `GET https://cellcast.com.au/api/v3/get-sms?message_id=<id>`

```ruby
response = client.sms.get_message(message_id: 'msg_123456789')
```

**Response Format:**
```json
{
  "meta": {
    "code": 200,
    "status": "SUCCESS"
  },
  "msg": "Record founded",
  "data": [
    {
      "to": "+61400000000",
      "body": "Hello World!",
      "sent_time": "2024-01-15 14:04:46",
      "message_id": "6EF87246-52D3-74FB-C319-NNNNNNN",
      "status": "Delivered",
      "subaccount_id": ""
    }
  ]
}
```

##### Get Inbound Messages
**Official Endpoint:** `GET https://cellcast.com.au/api/v3/get-responses?page=<page>&type=sms`

```ruby
response = client.sms.get_responses(page: 1, type: 'sms')
```

##### Send New Zealand SMS
**Official Endpoint:** `POST https://cellcast.com.au/api/v3/send-sms-nz`

```ruby
response = client.sms.send_message_nz(
  to: '+64211234567',
  message: 'Hello New Zealand!',
  sender_id: 'YourBrand'
)
```

##### Send Template Message
**Official Endpoint:** `POST https://cellcast.com.au/api/v3/send-sms-template`

```ruby
response = client.sms.send_message_template(
  template_id: 'template_123',
  numbers: [
    { number: '+61400000000', fname: 'John', lname: 'Doe' }
  ],
  sender_id: 'YourBrand'
)
```

##### Mark Inbound Messages as Read
**Official Endpoint:** `POST https://cellcast.com.au/api/v3/inbound-read`

```ruby
response = client.sms.mark_inbound_read(message_id: 'inbound_msg_123')
```

**Official Endpoint:** `POST https://cellcast.com.au/api/v3/inbound-read-bulk`

```ruby
response = client.sms.mark_inbound_read_bulk(timestamp: '2024-01-01 00:00:00')
```

#### Account Module (`client.account`)

##### Get Account Balance
**Official Endpoint:** `GET https://cellcast.com.au/api/v3/account`

```ruby
balance = client.account.get_account_balance
```

**Response Format:**
```json
{
  "meta": {
    "code": 200,
    "status": "SUCCESS"
  },
  "msg": "Here's your account",
  "data": {
    "account_name": "John Doe",
    "account_email": "john@example.com",
    "sms_balance": "125.50",
    "mms_balance": "50.00"
  }
}
```

##### Get Templates
**Official Endpoint:** `GET https://cellcast.com.au/api/v3/get-template`

```ruby
templates = client.account.get_templates
```

##### Get Opt-out List
**Official Endpoint:** `GET https://cellcast.com.au/api/v3/get-optout`

```ruby
optouts = client.account.get_optout_list
```

#### Sender ID Module (`client.sender_id`)

##### Register Alpha ID (Business Name)
**Official Endpoint:** `POST https://cellcast.com.au/api/v3/register-alpha-id`

```ruby
response = client.sender_id.register_alpha_id(
  alpha_id: 'YourBrand',         # Required: business name (max 11 chars)
  purpose: 'Customer notifications' # Required: purpose description
)
```

**Response Format:**
```json
{
  "meta": {
    "code": 200,
    "status": "SUCCESS"
  },
  "msg": "Alpha ID is successfully registered! Please check portal for Alpha ID status",
  "data": []
}
```

### Error Handling & Retry Logic

#### Error Class Hierarchy

```
Cellcast::SMS::Error
├── AuthenticationError      # 401 responses, invalid API key
├── ValidationError         # Parameter validation failures
├── APIError               # General API errors (4xx, 5xx)
│   ├── RateLimitError    # 429 responses, includes retry_after
│   └── ServerError       # 5xx responses
└── NetworkError           # Network-related errors
    ├── TimeoutError      # Request timeouts
    ├── ConnectionError   # Connection failures
    └── SSLError         # SSL/TLS errors
```

#### Retry Strategy

The gem uses a fixed retry strategy with exponential backoff:

- **Maximum Retries**: 3 attempts
- **Backoff Timing**: 1s → 2s → 4s (capped at 32 seconds)
- **Retry Conditions**:
  - Rate limit errors (429) - uses `Retry-After` header when available
  - Server errors (5xx)
  - Network errors (timeouts, connection failures)
- **No Retry Conditions**:
  - Authentication errors (401)
  - Validation errors (400, 422)
  - Client errors (other 4xx)

#### Error Handling Examples

```ruby
begin
  response = client.quick_send(
    to: '+1234567890',
    message: 'Test message'
  )
rescue Cellcast::SMS::AuthenticationError => e
  # API key is invalid or expired
  puts "Authentication failed: #{e.message}"
  # Action: Check API key, contact support if needed
  
rescue Cellcast::SMS::ValidationError => e
  # Invalid parameters
  puts "Validation error: #{e.message}"
  # Error messages include guidance:
  # "Phone number must be in international format (e.g., +1234567890)"
  
rescue Cellcast::SMS::RateLimitError => e
  # Rate limit exceeded
  puts "Rate limited: #{e.message}"
  if e.retry_after
    puts "Retry after: #{e.retry_after} seconds"
    sleep(e.retry_after)
    # Retry the request
  end
  
rescue Cellcast::SMS::NetworkError => e
  # Network connectivity issues
  puts "Network error: #{e.message}"
  # The gem already retried 3 times with exponential backoff
  # Consider checking network connectivity or trying again later
  
rescue Cellcast::SMS::ServerError => e
  # Cellcast API server error
  puts "Server error: #{e.message}"
  puts "Status: #{e.status_code}"
  # The gem already retried 3 times
  # Check Cellcast status page or contact support
  
rescue Cellcast::SMS::APIError => e
  # Other API errors
  puts "API error: #{e.message}"
  puts "Status: #{e.status_code}"
  puts "Response: #{e.response_body}"
end
```

### Configuration Options

#### Timeout Configuration

```ruby
# Configure timeouts (only essential options)
client = Cellcast.sms(
  api_key: 'your-api-key',
  open_timeout: 30,    # Connection timeout (seconds)
  read_timeout: 60,    # Read timeout (seconds)
  logger: Logger.new(STDOUT)  # Optional debug logging
)
```

### Response Objects

All methods now return raw API response `Hash` objects with the official Cellcast API structure:

```ruby
response = client.quick_send(to: '+1234567890', message: 'Hello!')

# Access response data directly from the Hash
puts "Status: #{response['status']}"
puts "Message: #{response['message']}"

# Navigate nested data structures
if response['status']
  message_id = response.dig('data', 'queueResponse', 0, 'MessageId')
  puts "Message ID: #{message_id}"
end

# Check for errors
if response['error'] && !response['error'].empty?
  puts "API Error: #{response['error']}"
end
```

### Testing & Development

#### Sandbox Mode for Cost-Free Testing

The gem includes a comprehensive sandbox mode that allows you to test your SMS integration without making live API calls or incurring costs. This is perfect for development, testing, and CI/CD pipelines.

##### Enabling Sandbox Mode

```ruby
# Enable sandbox mode (opt-in only, disabled by default)
config = Cellcast::SMS::Configuration.new
config.sandbox_mode = true

client = Cellcast.sms(api_key: 'test-key', config: config)

# All methods work identically, but no live calls are made
response = client.quick_send(to: '+1234567890', message: 'Test message')
puts response['status'] # => true (realistic mock response)
```

##### Special Test Numbers

Inspired by Stripe's test cards and Twilio's magic test numbers, the sandbox mode provides special phone numbers that trigger specific behaviors:

```ruby
'+15550000000' # → Always succeeds (queued status)
'+15550000001' # → Always fails (failed status)  
'+15550000002' # → Rate limited (throws RateLimitError)
'+15550000003' # → Invalid number (throws ValidationError)
'+15550000004' # → Insufficient credits (throws APIError)
```

Any other phone number defaults to successful behavior.

##### Special Test Message IDs

For testing the delete message functionality, sandbox mode provides special message IDs that trigger different behaviors:

```ruby
'sandbox_message_123'      # → Delete succeeds
'sandbox_notfound_123'     # → Message not found (404 error)
'sandbox_already_sent_123' # → Already sent, cannot delete (400 error)
'sandbox_fail_123'         # → Delete operation fails (500 error)
```

**Usage Examples:**
```ruby
# Test successful deletion
response = client.sms.delete_message(message_id: 'sandbox_message_123')
puts response['status'] # => true

# Test message not found scenario
begin
  client.sms.delete_message(message_id: 'sandbox_notfound_123')
rescue Cellcast::SMS::APIError => e
  puts "Error: #{e.message}" # => "Message not found"
  puts "Status: #{e.status_code}" # => 404
end

# Test already sent message scenario
begin
  client.cancel_message(message_id: 'sandbox_already_sent_456')
rescue Cellcast::SMS::APIError => e
  puts "Cannot delete: #{e.message}" # => "Cannot delete already sent message"
  puts "Status: #{e.status_code}" # => 400
end
```

Any other message ID defaults to successful deletion behavior.

##### Testing Error Scenarios

The special test numbers make it easy to test error handling:

```ruby
# Test rate limiting scenarios
begin
  client.quick_send(to: '+15550000002', message: 'Test')
rescue Cellcast::SMS::RateLimitError => e
  puts "Handle rate limiting: retry after #{e.retry_after} seconds"
end

# Test validation errors
begin
  client.quick_send(to: '+15550000003', message: 'Test')
rescue Cellcast::SMS::ValidationError => e
  puts "Validation error: #{e.message}"
end

# Test API errors (insufficient credits)
begin
  client.quick_send(to: '+15550000004', message: 'Test')
rescue Cellcast::SMS::APIError => e
  puts "API error: #{e.message}, Status: #{e.status_code}"
end
```

##### Comprehensive Sandbox Coverage

The sandbox mode supports all API endpoints with realistic responses:

```ruby
# SMS sending
response = client.quick_send(to: '+15550000000', message: 'Test')
puts "Message ID: #{response.dig('data', 'queueResponse', 0, 'MessageId')}"

# Bulk sending
broadcast = client.broadcast(
  to: ['+15550000000', '+15550000001', '+15551234567'],
  message: 'Test broadcast'
)
puts "Success: #{broadcast.dig('data', 'totalValidContact')}, Failed: #{broadcast.dig('data', 'totalInvalidContact')}"

# Account operations
balance = client.balance
puts "Balance: $#{balance.dig('data', 'balance')}"

usage = client.usage_report
puts "Messages sent: #{usage.dig('data', 'messages_sent')}"

# Sender ID operations
business_registration = client.sender_id.register_business_name(
  business_name: 'Test Company',
  business_registration: 'REG123',
  contact_info: { email: 'test@example.com', phone: '+15550000000' }
)
puts "Registration: #{business_registration['status']}"

# All other endpoints work similarly
```

##### Sandbox Response Format

Sandbox responses match the real API structure exactly:

```ruby
# Real API response structure is replicated
{
  "app_type" => "web",
  "app_version" => "1.0",
  "status" => true,
  "message" => "Request is being processed",
  "data" => {
    "queueResponse" => [
      {
        "Contact" => "+15550000000",
        "MessageId" => "sandbox_1641390000_1234",
        "Result" => "Message added to queue."
      }
    ],
    "totalValidContact" => 1,
    "totalInvalidContact" => 0
  },
  "error" => {}
}
```

##### Benefits of Sandbox Mode

- **💰 Zero Cost**: No charges for testing
- **🎯 Predictable**: Consistent responses for reliable tests
- **🧪 Error Testing**: Easy error scenario simulation
- **⚡ Fast**: Instant responses without network delays
- **🔒 Safe**: Perfect for CI/CD pipelines
- **📚 Developer Friendly**: Matches real API exactly

##### Example: Complete Test Suite

```ruby
# Test successful sending
def test_successful_send
  config = Cellcast::SMS::Configuration.new
  config.sandbox_mode = true
  client = Cellcast.sms(api_key: 'test', config: config)
  
  response = client.quick_send(to: '+15550000000', message: 'Test')
  assert response['status']
  assert_equal 'Request is being processed', response['message']
  assert response.dig('data', 'queueResponse', 0, 'MessageId').start_with?('sandbox_')
end

# Test error handling
def test_error_scenarios
  # Rate limiting
  assert_raises(Cellcast::SMS::RateLimitError) do
    client.quick_send(to: '+15550000002', message: 'Test')
  end
  
  # Invalid number
  assert_raises(Cellcast::SMS::ValidationError) do  
    client.quick_send(to: '+15550000003', message: 'Test')
  end
  
  # API error
  assert_raises(Cellcast::SMS::APIError) do
    client.quick_send(to: '+15550000004', message: 'Test')
  end
end
```

For a complete sandbox demonstration, see `examples/sandbox_mode.rb`.

#### Running Tests

```bash
# Run all tests
rake test

# Run specific test file
ruby test/test_sms_client.rb

# Run with verbose output
rake test TESTOPTS="-v"
```

#### Test Coverage

The gem includes comprehensive test coverage for:

- **Error Handling**: All error types and retry scenarios
- **Response Objects**: Raw response functionality
- **Convenience Methods**: Developer-friendly API operations
- **Validation**: Input parameter validation
- **Network Failures**: Timeout and connection error handling

#### Development Setup

```bash
# Clone repository
git clone https://github.com/timburgan/cellcast-sms.git
cd cellcast-sms

# Install dependencies
bundle install

# Run tests
rake test

# Build gem
gem build cellcast-sms.gemspec

# Install locally
gem install cellcast-sms-*.gem
```

#### API Testing

Use the provided test scenarios for comprehensive testing:

```ruby
# Test with invalid API key
client = Cellcast.sms(api_key: 'invalid-key')

begin
  client.quick_send(to: '+1234567890', message: 'Test')
rescue Cellcast::SMS::AuthenticationError => e
  puts "Expected authentication error: #{e.message}"
end

# Test rate limiting simulation
# (Rate limiting behavior can be tested with high-volume sends)

# Test network failure recovery
# (Network failures are handled automatically by retry logic)
```

### Security Considerations

#### API Key Management

```ruby
# ✅ Good: Use environment variables
client = Cellcast.sms(api_key: ENV['CELLCAST_API_KEY'])

# ❌ Bad: Hardcoded API keys
client = Cellcast.sms(api_key: 'your-actual-api-key')
```

#### Rate Limiting Awareness

```ruby
# Handle rate limiting gracefully in high-volume scenarios
begin
  response = client.broadcast(to: large_recipient_list, message: 'Announcement')
rescue Cellcast::SMS::RateLimitError => e
  puts "Rate limited. Retry after: #{e.retry_after} seconds"
  puts "Attempted URL: #{e.requested_url}"
  sleep(e.retry_after)
  # Retry the operation
end
```

#### Input Validation

The gem automatically validates all inputs before making API calls:

```ruby
# Phone number validation
client.quick_send(to: 'invalid-phone', message: 'Test')
# Raises: ValidationError with guidance on correct format

# Message length validation  
client.quick_send(to: '+1234567890', message: 'x' * 1601)
# Raises: ValidationError with maximum length information
```

#### Logging Considerations

```ruby
# Configure logging to avoid sensitive data exposure
logger = Logger.new(STDOUT)
logger.level = Logger::INFO  # Avoid DEBUG in production

client = Cellcast.sms(
  api_key: ENV['CELLCAST_API_KEY'],
  logger: logger
)

# API keys and message content are automatically masked in logs
```

### Performance Optimization

#### Bulk Operations

```ruby
# ✅ Efficient: Use broadcast for multiple recipients
client.broadcast(
  to: ['+1111111111', '+2222222222', '+3333333333'],
  message: 'Bulk message'
)

# ❌ Inefficient: Individual calls
phones.each do |phone|
  client.quick_send(to: phone, message: 'Individual message')
end
```

#### Account Balance Monitoring

```ruby
# ✅ Efficient: Check balance periodically for cost control
balance = client.balance
if balance.dig('data', 'balance').to_f < 10.0
  puts "Warning: Low balance - $#{balance.dig('data', 'balance')}"
  # Send alert or top up account
end

# ✅ Efficient: Monitor usage patterns
usage = client.usage_report
messages_sent = usage.dig('data', 'messages_sent') || 0
total_cost = usage.dig('data', 'total_cost') || 0

if messages_sent > 0
  puts "Usage this month: #{messages_sent} messages"
  puts "Average cost per message: $#{total_cost.to_f / messages_sent}"
end
```

#### Connection Reuse

The HTTP client automatically reuses connections for efficiency. No special configuration needed.

## Documentation

- **[Changelog](CHANGELOG.md)** - Version history and changes
- Official API documentation is at https://developer.cellcast.com

## Requirements

- Ruby 3.3.0 or higher

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/timburgan/cellcast-sms.

## License

Available under the [MIT License](LICENSE.txt).