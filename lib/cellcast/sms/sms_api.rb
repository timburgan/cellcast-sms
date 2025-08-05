# frozen_string_literal: true

module Cellcast
  module SMS
    # SMS API endpoints implementation
    # Following Sandi Metz rules: small class with focused responsibility
    class SMSApi
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
        @client.request(method: :post, path: "sms/send", body: body)
      end

      # Send bulk SMS messages
      # @param messages [Array<Hash>] Array of message hashes with :to, :message, and optional :sender_id
      # @param options [Hash] Additional options applied to all messages
      # @return [Hash] API response
      def send_bulk(messages:, **options)
        validate_bulk_messages(messages)

        body = build_bulk_message_body(messages, options)
        @client.request(method: :post, path: "sms/bulk", body: body)
      end

      # Get SMS message status
      # @param message_id [String] The message ID to check
      # @return [Hash] API response with message status
      def get_status(message_id:)
        validate_message_id(message_id)
        @client.request(method: :get, path: "sms/status/#{message_id}")
      end

      # Get SMS delivery report
      # @param message_id [String] The message ID
      # @return [Hash] API response with delivery report
      def get_delivery_report(message_id:)
        validate_message_id(message_id)
        @client.request(method: :get, path: "sms/delivery/#{message_id}")
      end

      # List sent SMS messages with optional filters
      # @param limit [Integer] Number of messages to retrieve (max 100)
      # @param offset [Integer] Offset for pagination
      # @param date_from [String] Start date filter (ISO 8601)
      # @param date_to [String] End date filter (ISO 8601)
      # @return [Hash] API response with message list
      def list_messages(limit: 50, offset: 0, date_from: nil, date_to: nil)
        params = build_list_params(limit, offset, date_from, date_to)
        path = "sms/messages"
        path += "?#{params}" unless params.empty?
        
        @client.request(method: :get, path: path)
      end

      private

      def validate_phone_number(phone)
        raise ValidationError, "Phone number cannot be nil or empty" if phone.nil? || phone.strip.empty?
        raise ValidationError, "Phone number must be a string" unless phone.is_a?(String)
      end

      def validate_message(message)
        raise ValidationError, "Message cannot be nil or empty" if message.nil? || message.strip.empty?
        raise ValidationError, "Message must be a string" unless message.is_a?(String)
        raise ValidationError, "Message too long (max 1600 characters)" if message.length > 1600
      end

      def validate_message_id(message_id)
        raise ValidationError, "Message ID cannot be nil or empty" if message_id.nil? || message_id.strip.empty?
      end

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
          message: message
        }
        
        body[:sender_id] = sender_id if sender_id
        body.merge!(options)
        body
      end

      def build_bulk_message_body(messages, options)
        {
          messages: messages.map { |msg| build_message_entry(msg, options) }
        }
      end

      def build_message_entry(message, global_options)
        entry = {
          to: message[:to],
          message: message[:message]
        }
        
        entry[:sender_id] = message[:sender_id] if message[:sender_id]
        entry.merge!(global_options)
        entry
      end

      def build_list_params(limit, offset, date_from, date_to)
        params = []
        
        if limit && (1..100).cover?(limit)
          params << "limit=#{limit}"
        end
        
        params << "offset=#{offset}" if offset && offset >= 0
        params << "date_from=#{date_from}" if date_from
        params << "date_to=#{date_to}" if date_to
        
        params.join("&")
      end
    end
  end
end