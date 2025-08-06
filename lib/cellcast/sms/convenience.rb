# frozen_string_literal: true

module Cellcast
  module SMS
    # Convenience methods and simplified interface for common operations
    # Provides a more developer-friendly API while maintaining full flexibility
    module ConvenienceMethods
      # Send a quick SMS with minimal configuration
      # @param to [String] Phone number to send to
      # @param message [String] Message content
      # @param from [String, nil] Optional sender ID
      # @return [SendMessageResponse] Wrapped response
      def quick_send(to:, message:, from: nil)
        response = sms.send_message(to: to, message: message, sender_id: from)
        SendMessageResponse.new(response)
      end

      # Send SMS to multiple recipients with the same message
      # @param to [Array<String>] Array of phone numbers
      # @param message [String] Message content
      # @param from [String, nil] Optional sender ID
      # @return [BulkMessageResponse] Wrapped response
      def broadcast(to:, message:, from: nil)
        messages = to.map { |phone| { to: phone, message: message, sender_id: from }.compact }
        response = sms.send_bulk(messages: messages)
        BulkMessageResponse.new(response)
      end

      # Check if a message was delivered successfully
      # @param message_id [String] The message ID to check
      # @return [Boolean] True if delivered, false otherwise
      def delivered?(message_id:)
        status_response = check_status(message_id: message_id)
        status_response.delivered?
      end

      # Get message status with wrapped response
      # @param message_id [String] The message ID to check
      # @return [MessageStatusResponse] Wrapped response
      def check_status(message_id:)
        response = sms.get_status(message_id: message_id)
        MessageStatusResponse.new(response)
      end

      # Get unread incoming messages
      # @param limit [Integer] Maximum number of messages to return
      # @return [IncomingListResponse] Wrapped response with unread messages
      def unread_messages(limit: 50)
        response = incoming.list_incoming(limit: limit, unread_only: true)
        IncomingListResponse.new(response)
      end

      # Mark all messages as read
      # @param message_ids [Array<String>] Array of message IDs to mark as read
      # @return [Response] API response
      def mark_all_read(message_ids:)
        response = incoming.mark_as_read(message_ids: message_ids)
        Response.new(response)
      end

      # Get conversation history for a sent message
      # @param original_message_id [String] The original message ID
      # @return [IncomingListResponse] All replies to the message
      def conversation_history(original_message_id:)
        response = incoming.get_replies(original_message_id: original_message_id)
        IncomingListResponse.new(response)
      end

      # Setup basic webhook for SMS events
      # @param url [String] Webhook URL
      # @param events [Array<String>, nil] Events to subscribe to (defaults to all SMS events)
      # @return [Response] Webhook configuration response
      def setup_webhook(url:, events: nil)
        events ||= %w[sms.sent sms.delivered sms.failed sms.received sms.reply]
        response = webhook.configure_webhook(url: url, events: events)
        Response.new(response)
      end

      # Test webhook configuration
      # @return [Response] Test result
      def test_webhook
        response = webhook.test_webhook
        Response.new(response)
      end
    end
  end
end
