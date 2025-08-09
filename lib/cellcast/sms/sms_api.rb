# frozen_string_literal: true

module Cellcast
  module SMS
    # SMS API endpoints implementation
    # Following Sandi Metz rules: small class with focused responsibility
    class SMSApi
      include Validator

      def initialize(client)
        @client = client
      end

      # Send a single SMS message
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
      # @param messages [Array<Hash>] Array of message hashes with :to, :message, and optional :sender_id
      # @param options [Hash] Additional options applied to all messages
      # @return [Hash] API response
      def send_bulk(messages:, **options)
        validate_bulk_messages(messages)

        body = build_bulk_message_body(messages, options)
        @client.request(method: :post, path: "api/v1/gateway/bulk", body: body)
      end

      # Get SMS message status
      # @param message_id [String] The message ID to check
      # @return [Hash] API response with message status
      def get_status(message_id:)
        validate_message_id(message_id)
        @client.request(method: :get, path: "api/v1/gateway/status/#{message_id}")
      end

      # Get SMS delivery report
      # @param message_id [String] The message ID
      # @return [Hash] API response with delivery report
      def get_delivery_report(message_id:)
        validate_message_id(message_id)
        @client.request(method: :get, path: "api/v1/gateway/delivery/#{message_id}")
      end

      # List sent SMS messages with optional filters
      # @param limit [Integer] Number of messages to retrieve (max 100)
      # @param offset [Integer] Offset for pagination
      # @param date_from [String] Start date filter (ISO 8601)
      # @param date_to [String] End date filter (ISO 8601)
      # @return [Hash] API response with message list
      def list_messages(limit: 50, offset: 0, date_from: nil, date_to: nil)
        params = build_list_params(limit, offset, date_from, date_to)
        path = "api/v1/gateway/messages"
        path += "?#{params}" unless params.empty?

        @client.request(method: :get, path: path)
      end

      # Delete a scheduled SMS message by message ID
      # This is primarily used to cancel scheduled messages that haven't been sent yet.
      # Note: The official API endpoint name "Delete Sent SMS Message" may be misleading,
      # but this is typically used for canceling future scheduled messages.
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

      def build_list_params(limit, offset, date_from, date_to)
        params = []

        params << "limit=#{limit}" if limit && (1..100).cover?(limit)

        params << "offset=#{offset}" if offset && offset >= 0
        params << "date_from=#{date_from}" if date_from
        params << "date_to=#{date_to}" if date_to

        params.join("&")
      end
    end
  end
end
