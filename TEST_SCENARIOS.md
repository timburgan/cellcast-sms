# Test Scenarios for Cellcast SMS Gem

This document outlines test scenarios, edge cases, and boundary tests for the Cellcast SMS Ruby gem. These tests should be implemented using Minitest when the testing phase begins.

## Client Initialization Tests

### Valid Cases
- [ ] Initialize client with valid API key and default base URL
- [ ] Initialize client with valid API key and custom base URL
- [ ] API key with leading/trailing whitespace is trimmed

### Edge Cases
- [ ] Initialize with nil API key raises ValidationError
- [ ] Initialize with empty string API key raises ValidationError
- [ ] Initialize with whitespace-only API key raises ValidationError
- [ ] Initialize with custom base URL that has trailing slash
- [ ] Initialize with HTTP (non-HTTPS) base URL

### Boundary Tests
- [ ] Very long API key (1000+ characters)
- [ ] API key with special characters and unicode
- [ ] Base URL with various valid formats

## SMS API Tests

### Send Single Message - Valid Cases
- [ ] Send SMS with all required parameters
- [ ] Send SMS with optional sender_id
- [ ] Send SMS with additional options
- [ ] Message with exactly 160 characters (single SMS)
- [ ] Message with exactly 1600 characters (maximum)

### Send Single Message - Edge Cases
- [ ] Send SMS with nil phone number raises ValidationError
- [ ] Send SMS with empty phone number raises ValidationError
- [ ] Send SMS with nil message raises ValidationError
- [ ] Send SMS with empty message raises ValidationError
- [ ] Send SMS with non-string phone number raises ValidationError
- [ ] Send SMS with non-string message raises ValidationError

### Send Single Message - Boundary Tests
- [ ] Message with 1 character
- [ ] Message with 1601 characters raises ValidationError
- [ ] Phone number with various international formats
- [ ] Message with emoji and unicode characters
- [ ] Message with only whitespace

### Send Bulk Messages - Valid Cases
- [ ] Send bulk with 2 messages
- [ ] Send bulk with 1000 messages (maximum)
- [ ] Send bulk with mixed sender IDs
- [ ] Send bulk with global options applied to all messages

### Send Bulk Messages - Edge Cases
- [ ] Send bulk with nil messages raises ValidationError
- [ ] Send bulk with empty array raises ValidationError
- [ ] Send bulk with non-array messages raises ValidationError
- [ ] Send bulk with 1001 messages raises ValidationError
- [ ] Message object missing :to key raises ValidationError
- [ ] Message object missing :message key raises ValidationError
- [ ] Message object with invalid phone number raises ValidationError
- [ ] Message object with invalid message content raises ValidationError

### Send Bulk Messages - Boundary Tests
- [ ] Single message in bulk array
- [ ] All messages with maximum length content
- [ ] Mixed valid and edge-case phone number formats

### Message Status and Reports - Valid Cases
- [ ] Get status with valid message ID
- [ ] Get delivery report with valid message ID

### Message Status and Reports - Edge Cases
- [ ] Get status with nil message ID raises ValidationError
- [ ] Get status with empty message ID raises ValidationError
- [ ] Get delivery report with nil message ID raises ValidationError
- [ ] Get delivery report with empty message ID raises ValidationError

### List Messages - Valid Cases
- [ ] List messages with default parameters
- [ ] List messages with custom limit (1-100)
- [ ] List messages with custom offset
- [ ] List messages with date filters
- [ ] List messages with all parameters

### List Messages - Boundary Tests
- [ ] List with limit = 1
- [ ] List with limit = 100
- [ ] List with limit = 0 (should use default)
- [ ] List with limit > 100 (should use max 100)
- [ ] List with negative offset (should use 0)
- [ ] List with very large offset

## Sender ID API Tests

### Business Name Registration - Valid Cases
- [ ] Register business name with all required fields
- [ ] Register with various business name formats
- [ ] Register with complete contact information

### Business Name Registration - Edge Cases
- [ ] Register with nil business name raises ValidationError
- [ ] Register with empty business name raises ValidationError
- [ ] Register with non-string business name raises ValidationError
- [ ] Register with business name > 50 characters raises ValidationError
- [ ] Register with nil business registration raises ValidationError
- [ ] Register with empty business registration raises ValidationError
- [ ] Register with non-hash contact info raises ValidationError
- [ ] Register with contact info missing email raises ValidationError
- [ ] Register with contact info missing phone raises ValidationError

### Business Name Registration - Boundary Tests
- [ ] Business name with exactly 50 characters
- [ ] Business name with 51 characters raises ValidationError
- [ ] Business name with 1 character
- [ ] Contact info with minimal valid fields
- [ ] Contact info with additional optional fields

### Custom Number Registration - Valid Cases
- [ ] Register custom number with valid phone and purpose
- [ ] Verify custom number with valid code
- [ ] Get status for registered custom number

### Custom Number Registration - Edge Cases
- [ ] Register with nil phone number raises ValidationError
- [ ] Register with empty phone number raises ValidationError
- [ ] Register with nil purpose raises ValidationError
- [ ] Register with empty purpose raises ValidationError
- [ ] Verify with nil phone number raises ValidationError
- [ ] Verify with nil verification code raises ValidationError
- [ ] Verify with empty verification code raises ValidationError

### Sender ID Listing - Valid Cases
- [ ] List all sender IDs without filters
- [ ] List with type filter ('business_name' or 'custom_number')
- [ ] List with status filter
- [ ] List with both type and status filters

## Token API Tests

### Token Operations - Valid Cases
- [ ] Verify token returns valid response
- [ ] Get token info returns permissions and limits
- [ ] Get usage stats with default period
- [ ] Get usage stats with each valid period ('daily', 'weekly', 'monthly')

### Token Operations - Edge Cases
- [ ] Get usage stats with invalid period raises ValidationError
- [ ] Get usage stats with nil period raises ValidationError

## Webhook API Tests

### Webhook Configuration - Valid Cases
- [ ] Configure webhook with HTTP URL
- [ ] Configure webhook with HTTPS URL
- [ ] Configure webhook with valid events array
- [ ] Configure webhook with optional secret
- [ ] Get current webhook configuration
- [ ] Delete webhook configuration

### Webhook Configuration - Edge Cases
- [ ] Configure with nil URL raises ValidationError
- [ ] Configure with empty URL raises ValidationError
- [ ] Configure with non-string URL raises ValidationError
- [ ] Configure with invalid URL format raises ValidationError
- [ ] Configure with non-HTTP/HTTPS URL raises ValidationError
- [ ] Configure with nil events raises ValidationError
- [ ] Configure with empty events array raises ValidationError
- [ ] Configure with non-array events raises ValidationError
- [ ] Configure with invalid event names raises ValidationError

### Webhook Testing and Logs - Valid Cases
- [ ] Test webhook with default event type
- [ ] Test webhook with each valid event type
- [ ] Get delivery logs with default pagination
- [ ] Get delivery logs with custom pagination
- [ ] Retry failed delivery with valid delivery ID

### Webhook Testing and Logs - Edge Cases
- [ ] Test webhook with invalid event type raises ValidationError
- [ ] Get logs with limit < 1 raises ValidationError
- [ ] Get logs with limit > 100 raises ValidationError
- [ ] Get logs with negative offset raises ValidationError
- [ ] Retry delivery with nil delivery ID raises ValidationError
- [ ] Retry delivery with empty delivery ID raises ValidationError

### Webhook Testing and Logs - Boundary Tests
- [ ] Get logs with limit = 1
- [ ] Get logs with limit = 100
- [ ] Get logs with offset = 0
- [ ] Get logs with very large offset

## HTTP Client Tests

### Request Building - Valid Cases
- [ ] Build GET request with proper headers
- [ ] Build POST request with JSON body
- [ ] Build PUT request with custom headers
- [ ] Build DELETE request
- [ ] Request includes proper User-Agent header
- [ ] Request includes proper Authorization header
- [ ] Request includes proper Content-Type header

### Request Building - Edge Cases
- [ ] Build request with unsupported HTTP method raises ValidationError
- [ ] Build request with nil method raises ValidationError

### Response Handling - Valid Cases
- [ ] Handle 200 response with JSON body
- [ ] Handle 201 response with JSON body
- [ ] Handle response with empty body
- [ ] Handle response with non-JSON body

### Response Handling - Error Cases
- [ ] Handle 401 response raises AuthenticationError
- [ ] Handle 429 response raises RateLimitError with status and body
- [ ] Handle 400-499 response raises APIError with status and body
- [ ] Handle 500-599 response raises ServerError with status and body
- [ ] Handle unexpected status code raises APIError

### Network Conditions - Edge Cases
- [ ] Handle connection timeout
- [ ] Handle read timeout
- [ ] Handle network unreachable
- [ ] Handle invalid SSL certificate
- [ ] Handle malformed JSON response

## Integration Tests

### End-to-End Scenarios
- [ ] Complete SMS sending workflow with status check
- [ ] Complete sender ID registration and verification workflow
- [ ] Complete webhook setup and testing workflow
- [ ] Token verification and usage tracking workflow

### Error Recovery Tests
- [ ] Retry failed API calls with exponential backoff
- [ ] Handle rate limiting gracefully
- [ ] Recover from temporary network failures
- [ ] Handle API maintenance windows

## Performance Tests

### Load Testing
- [ ] Send bulk SMS with maximum batch size
- [ ] Handle multiple concurrent API calls
- [ ] Memory usage with large response payloads
- [ ] Performance with frequent status checks

### Stress Testing
- [ ] API behavior under rate limiting
- [ ] Client behavior with very long response times
- [ ] Memory management with long-running processes

## Security Tests

### Authentication
- [ ] Invalid API key returns proper error
- [ ] Expired API key handling
- [ ] API key in logs is properly masked
- [ ] Webhook secret validation

### Data Validation
- [ ] SQL injection prevention in parameters
- [ ] XSS prevention in message content
- [ ] Phone number format validation
- [ ] URL validation for webhooks

## Compatibility Tests

### Ruby Versions
- [ ] Gem works with Ruby 3.3.0
- [ ] Gem works with Ruby 3.3.x latest
- [ ] Gem fails gracefully on Ruby < 3.3

### Platform Tests
- [ ] Works on Linux systems
- [ ] Works on macOS systems
- [ ] Works on Windows systems
- [ ] Works in Docker containers

## Documentation Tests

### Code Examples
- [ ] All README examples execute without errors
- [ ] All method documentation examples are valid
- [ ] API documentation matches implementation

### Error Messages
- [ ] All error messages are helpful and actionable
- [ ] Error messages don't expose sensitive information
- [ ] Validation errors include expected formats