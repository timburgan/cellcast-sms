# frozen_string_literal: true

module Cellcast
  module SMS
    # SMS API endpoints implementation - only officially documented endpoints
    # Based on official Cellcast API documentation:
    # - POST api/v1/gateway (single and bulk SMS)
    # - DELETE api/v1/gateway/messages/{messageId} (delete message)
    class SMSApi
      include Validator

      def initialize(client)
        @client = client
      end

      # Send a single SMS message
      # Official endpoint: POST https://api.cellcast.com/api/v1/gateway
      # @param to [String] The recipient phone number
      # @param message [String] The SMS message content
      # @param sender_id [String, nil] Optional sender ID
      # @param options [Hash] Additional options
      # @return [Hash] API response
      def send_message(to:, message:, sender_id: nil, **options)
        validate_phone_number(to)
        validate_message(message)

        body = build_send_message_body(to, message, sender_id, options)
        @client.request(method: :post, path: "api/v1/gateway", body: body)
      end

      # Send bulk SMS messages
      # Official endpoint: POST https://api.cellcast.com/api/v1/gateway (same as single SMS)
      # @param messages [Array<Hash>] Array of message hashes with :to, :message, and optional :sender_id
      # @param options [Hash] Additional options applied to all messages
      # @return [Hash] API response
      def send_bulk(messages:, **options)
        validate_bulk_messages(messages)

        body = build_bulk_message_body(messages, options)
        @client.request(method: :post, path: "api/v1/gateway", body: body)
      end

      # Delete a scheduled SMS message by message ID
      # Official endpoint: DELETE https://api.cellcast.com/api/v1/gateway/messages/{messageId}
      # This is primarily used to cancel scheduled messages that haven't been sent yet.
      # @param message_id [String] The message ID to delete
      # @return [Hash] API response confirming deletion
      def delete_message(message_id:)
        validate_message_id(message_id)
        @client.request(method: :delete, path: "api/v1/gateway/messages/#{message_id}")
      end

      private

      def validate_bulk_messages(messages)
        raise ValidationError, "Messages must be an array" unless messages.is_a?(Array)
        raise ValidationError, "Messages array cannot be empty" if messages.empty?
        raise ValidationError, "Too many messages (max 1000)" if messages.length > 1000

        messages.each_with_index do |msg, index|
          raise ValidationError, "Message at index #{index} must be a hash" unless msg.is_a?(Hash)
          raise ValidationError, "Message at index #{index} missing :to" unless msg.key?(:to)
          raise ValidationError, "Message at index #{index} missing :message" unless msg.key?(:message)

          validate_phone_number(msg[:to])
          validate_message(msg[:message])
        end
      end

      def build_send_message_body(to, message, sender_id, options)
        body = {
          to: to,
          message: message,
        }

        body[:sender_id] = sender_id if sender_id
        body.merge!(options)
        body
      end

      def build_bulk_message_body(messages, options)
        {
          messages: messages.map { |msg| build_message_entry(msg, options) },
        }
      end

      def build_message_entry(message, global_options)
        entry = {
          to: message[:to],
          message: message[:message],
        }

        entry[:sender_id] = message[:sender_id] if message[:sender_id]
        entry.merge!(global_options)
        entry
      end
    end
  end
end
