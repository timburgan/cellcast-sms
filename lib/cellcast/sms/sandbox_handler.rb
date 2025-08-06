# frozen_string_literal: true

require 'time'

module Cellcast
  module SMS
    # Handles sandbox mode mock responses
    # Provides realistic responses without making actual API calls
    class SandboxHandler
      # Special test numbers that trigger specific behaviors
      SANDBOX_TEST_NUMBERS = {
        '+15550000000' => :success,
        '+15550000001' => :failed,
        '+15550000002' => :rate_limited,
        '+15550000003' => :invalid_number,
        '+15550000004' => :insufficient_credits
      }.freeze

      def initialize(logger: nil)
        @logger = logger
      end

      # Handle sandbox requests based on method and path
      def handle_request(method:, path:, body: nil)
        log_sandbox_request(method, path, body) if @logger

        case path
        when /^sms\/send$/
          handle_send_message(body)
        when /^sms\/bulk$/
          handle_bulk_send(body)
        when /^sms\/status\/(.+)$/
          handle_message_status($1)
        when /^sms\/delivery\/(.+)$/
          handle_delivery_report($1)
        when /^sms\/incoming/
          handle_incoming_messages
        when /^sms\/messages/
          handle_list_messages
        when /^sms\/mark-read$/
          handle_mark_read(body)
        when /^sms\/replies\/(.+)$/
          handle_replies($1)
        when /^webhooks?/
          handle_webhook_request(method, path, body)
        when /^sender-ids?/
          handle_sender_id_request(method, path, body)
        when /^auth\//
          handle_token_request(method, path, body)
        else
          handle_generic_success
        end
      end

      private

      def handle_send_message(body)
        phone_number = body&.dig('to') || body&.dig(:to)
        behavior = SANDBOX_TEST_NUMBERS[phone_number] || :success

        case behavior
        when :success
          success_send_response(phone_number)
        when :failed
          failed_send_response(phone_number)
        when :rate_limited
          rate_limit_error
        when :invalid_number
          invalid_number_error(phone_number)
        when :insufficient_credits
          insufficient_credits_error
        else
          success_send_response(phone_number)
        end
      end

      def handle_bulk_send(body)
        messages = body&.dig('messages') || body&.dig(:messages) || []
        response_messages = messages.map do |msg|
          phone_number = msg['to'] || msg[:to]
          behavior = SANDBOX_TEST_NUMBERS[phone_number] || :success
          
          case behavior
          when :success
            success_send_response(phone_number, bulk: true)
          when :failed
            failed_send_response(phone_number, bulk: true)
          when :invalid_number
            invalid_number_send_response(phone_number, bulk: true)
          else
            success_send_response(phone_number, bulk: true)
          end
        end

        {
          'messages' => response_messages,
          'total_count' => response_messages.length,
          'successful_count' => response_messages.count { |msg| msg['status'] != 'failed' },
          'failed_count' => response_messages.count { |msg| msg['status'] == 'failed' },
          'total_cost' => response_messages.sum { |msg| msg['cost'].to_f }
        }
      end

      def handle_message_status(message_id)
        # Simulate different statuses based on message ID pattern
        status = if message_id.include?('fail')
                   'failed'
                 elsif message_id.include?('pending')
                   'sent'
                 else
                   'delivered'
                 end

        {
          'id' => message_id,
          'message_id' => message_id,
          'status' => status,
          'delivered_at' => status == 'delivered' ? Time.now.utc.iso8601 : nil,
          'failed_reason' => status == 'failed' ? 'Invalid destination number' : nil
        }
      end

      def handle_delivery_report(message_id)
        handle_message_status(message_id).merge({
          'delivery_report' => {
            'delivered_at' => Time.now.utc.iso8601,
            'network_status' => 'DELIVRD'
          }
        })
      end

      def handle_list_messages
        {
          'data' => [
            {
              'id' => 'sandbox_msg_001',
              'message_id' => 'sandbox_msg_001',
              'to' => '+15551234567',
              'message' => 'Sandbox test message',
              'status' => 'delivered',
              'cost' => 0.05,
              'parts' => 1,
              'created_at' => (Time.now - 3600).utc.iso8601,
              'delivered_at' => Time.now.utc.iso8601
            }
          ],
          'total' => 1,
          'limit' => 50,
          'offset' => 0
        }
      end

      def handle_incoming_messages
        {
          'data' => [
            {
              'id' => 'sandbox_incoming_001',
              'from' => '+15551234567',
              'to' => '+15550987654',
              'message' => 'Thanks for the update!',
              'received_at' => Time.now.utc.iso8601,
              'read' => false,
              'original_message_id' => 'sandbox_msg_001'
            }
          ],
          'total' => 1,
          'limit' => 50,
          'offset' => 0
        }
      end

      def handle_mark_read(body)
        message_ids = body&.dig('message_ids') || body&.dig(:message_ids) || []
        {
          'marked_read' => message_ids.length,
          'message_ids' => message_ids
        }
      end

      def handle_replies(original_message_id)
        # Extract just the message ID part, ignoring query parameters
        message_id = original_message_id.split('?').first
        
        {
          'data' => [
            {
              'id' => 'sandbox_reply_001',
              'from' => '+15551234567',
              'to' => '+15550987654',
              'message' => 'This is a reply to your message',
              'received_at' => Time.now.utc.iso8601,
              'read' => false,
              'original_message_id' => message_id
            }
          ],
          'total' => 1,
          'limit' => 50,
          'offset' => 0
        }
      end

      def handle_webhook_request(method, path, body)
        if method.to_s.upcase == 'POST' && path.include?('configure')
          {
            'webhook_id' => 'sandbox_webhook_001',
            'url' => body&.dig('url') || body&.dig(:url),
            'events' => body&.dig('events') || body&.dig(:events) || [],
            'active' => true,
            'created_at' => Time.now.utc.iso8601
          }
        elsif path.include?('test')
          {
            'test_sent' => true,
            'webhook_id' => 'sandbox_webhook_001',
            'test_payload' => {
              'event' => 'sms.delivered',
              'message_id' => 'sandbox_test_msg',
              'status' => 'delivered'
            }
          }
        elsif path.include?('config') && method.to_s.upcase == 'GET'
          {
            'webhook_id' => 'sandbox_webhook_001',
            'url' => 'https://example.com/webhook',
            'events' => ['sms.sent', 'sms.delivered', 'sms.received'],
            'active' => true,
            'created_at' => Time.now.utc.iso8601
          }
        elsif path.include?('logs')
          {
            'data' => [
              {
                'delivery_id' => 'sandbox_delivery_001',
                'webhook_id' => 'sandbox_webhook_001',
                'event_type' => 'sms.delivered',
                'status' => 'success',
                'delivered_at' => Time.now.utc.iso8601,
                'response_code' => 200
              }
            ],
            'total' => 1,
            'limit' => 50,
            'offset' => 0
          }
        elsif path.include?('retry')
          {
            'retry_sent' => true,
            'delivery_id' => body&.dig('delivery_id') || body&.dig(:delivery_id),
            'status' => 'success'
          }
        else
          handle_generic_success
        end
      end

      def handle_sender_id_request(method, path, body)
        if method.to_s.upcase == 'POST' && path.include?('business-name')
          {
            'sender_id' => 'SANDBOX',
            'status' => 'pending',
            'business_name' => body&.dig('business_name') || body&.dig(:business_name),
            'created_at' => Time.now.utc.iso8601
          }
        elsif method.to_s.upcase == 'POST' && path.include?('custom-number')
          {
            'sender_id' => body&.dig('phone_number') || body&.dig(:phone_number),
            'status' => 'pending',
            'verification_required' => true,
            'created_at' => Time.now.utc.iso8601
          }
        elsif method.to_s.upcase == 'POST' && path.include?('verify-custom-number')
          {
            'sender_id' => body&.dig('phone_number') || body&.dig(:phone_number),
            'status' => 'approved',
            'verified_at' => Time.now.utc.iso8601
          }
        else
          {
            'sender_ids' => [
              {
                'id' => 'sandbox_sender_001',
                'sender_id' => 'SANDBOX',
                'type' => 'business_name',
                'status' => 'approved',
                'created_at' => Time.now.utc.iso8601
              }
            ],
            'total' => 1
          }
        end
      end

      def handle_token_request(method, path, body)
        if path.include?('verify-token')
          {
            'valid' => true,
            'token_id' => 'sandbox_token_001',
            'permissions' => ['sms.send', 'sms.receive', 'webhook.manage'],
            'expires_at' => (Time.now + 365 * 24 * 3600).utc.iso8601
          }
        elsif path.include?('token-info')
          {
            'token_id' => 'sandbox_token_001',
            'name' => 'Sandbox Token',
            'permissions' => ['sms.send', 'sms.receive', 'webhook.manage'],
            'created_at' => Time.now.utc.iso8601,
            'last_used' => Time.now.utc.iso8601
          }
        elsif path.include?('usage-stats')
          {
            'period' => 'daily',
            'messages_sent' => 42,
            'messages_received' => 8,
            'total_cost' => 2.10,
            'webhook_deliveries' => 50,
            'api_calls' => 150
          }
        elsif path.include?('refresh-token')
          {
            'token_id' => 'sandbox_token_002',
            'token' => 'sandbox_new_token_value',
            'expires_at' => (Time.now + 365 * 24 * 3600).utc.iso8601
          }
        else
          # Default response for verify_token (most common case)
          {
            'valid' => true,
            'token_id' => 'sandbox_token_001',
            'permissions' => ['sms.send', 'sms.receive', 'webhook.manage'],
            'expires_at' => (Time.now + 365 * 24 * 3600).utc.iso8601
          }
        end
      end

      def handle_generic_success
        {
          'success' => true,
          'sandbox_mode' => true,
          'timestamp' => Time.now.utc.iso8601
        }
      end

      # Response builders
      def success_send_response(phone_number, bulk: false)
        response = {
          'id' => generate_message_id,
          'message_id' => generate_message_id,
          'to' => phone_number,
          'status' => 'queued',
          'cost' => 0.05,
          'parts' => 1,
          'created_at' => Time.now.utc.iso8601
        }
        
        bulk ? response : response.merge('message' => 'Sandbox test message')
      end

      def failed_send_response(phone_number, bulk: false)
        response = {
          'id' => generate_message_id,
          'message_id' => generate_message_id,
          'to' => phone_number,
          'status' => 'failed',
          'cost' => 0.0,
          'parts' => 1,
          'failed_reason' => 'Sandbox test failure',
          'created_at' => Time.now.utc.iso8601
        }
        
        bulk ? response : response.merge('message' => 'Sandbox test message')
      end

      def invalid_number_send_response(phone_number, bulk: false)
        response = {
          'id' => generate_message_id,
          'message_id' => generate_message_id,
          'to' => phone_number,
          'status' => 'failed',
          'cost' => 0.0,
          'parts' => 1,
          'failed_reason' => 'Invalid destination number',
          'created_at' => Time.now.utc.iso8601
        }
        
        bulk ? response : response.merge('message' => 'Sandbox test message')
      end

      # Error responses that raise exceptions
      def rate_limit_error
        raise RateLimitError.new(
          "Rate limit exceeded in sandbox mode",
          status_code: 429,
          response_body: { error: "Rate limit exceeded" }.to_json,
          retry_after: 60
        )
      end

      def invalid_number_error(phone_number)
        raise ValidationError, "Invalid phone number format: #{phone_number} (sandbox mode)"
      end

      def insufficient_credits_error
        raise APIError.new(
          "Insufficient credits (sandbox mode)",
          status_code: 402,
          response_body: { error: "Insufficient credits" }.to_json
        )
      end

      def generate_message_id
        "sandbox_#{Time.now.to_i}_#{rand(1000..9999)}"
      end

      def log_sandbox_request(method, path, body)
        @logger.info("Sandbox request: #{method.upcase} #{path}")
        @logger.debug("Sandbox request body: #{body}") if body
      end
    end
  end
end