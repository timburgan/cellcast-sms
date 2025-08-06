# frozen_string_literal: true

module Cellcast
  module SMS
    # Incoming SMS API endpoints implementation
    # Following Sandi Metz rules: small focused class for incoming message management
    class IncomingApi
      include Validator

      def initialize(client)
        @client = client
      end

      # List incoming SMS messages and replies
      # @param limit [Integer] Number of messages to retrieve (max 100)
      # @param offset [Integer] Offset for pagination
      # @param date_from [String] Start date filter (ISO 8601)
      # @param date_to [String] End date filter (ISO 8601)
      # @param sender_id [String, nil] Filter by specific sender ID
      # @param unread_only [Boolean] Only return unread messages
      # @return [Hash] API response with incoming message list
      def list_incoming(limit: 50, offset: 0, date_from: nil, date_to: nil, sender_id: nil, unread_only: false)
        params = build_list_params(limit, offset, date_from, date_to, sender_id, unread_only)
        path = "sms/incoming"
        path += "?#{params}" unless params.empty?

        @client.request(method: :get, path: path)
      end

      # Get details of a specific incoming message
      # @param message_id [String] The incoming message ID
      # @return [Hash] API response with message details
      def get_incoming_message(message_id:)
        validate_message_id(message_id)
        @client.request(method: :get, path: "sms/incoming/#{message_id}")
      end

      # Mark one or more incoming messages as read
      # @param message_ids [Array<String>] Array of message IDs to mark as read
      # @return [Hash] API response
      def mark_as_read(message_ids:)
        validate_message_ids(message_ids)

        body = { message_ids: message_ids }
        @client.request(method: :post, path: "sms/mark-read", body: body)
      end

      # Get replies to a specific sent message
      # @param original_message_id [String] The ID of the original sent message
      # @param limit [Integer] Number of replies to retrieve
      # @param offset [Integer] Offset for pagination
      # @return [Hash] API response with replies
      def get_replies(original_message_id:, limit: 50, offset: 0)
        validate_message_id(original_message_id)
        validate_pagination_params(limit, offset)

        params = "limit=#{limit}&offset=#{offset}"
        path = "sms/replies/#{original_message_id}?#{params}"

        @client.request(method: :get, path: path)
      end

      private

      def build_list_params(limit, offset, date_from, date_to, sender_id, unread_only)
        params = []

        params << "limit=#{limit}" if limit && (1..100).cover?(limit)

        params << "offset=#{offset}" if offset && offset >= 0
        params << "date_from=#{date_from}" if date_from
        params << "date_to=#{date_to}" if date_to
        params << "sender_id=#{sender_id}" if sender_id
        params << "unread_only=true" if unread_only

        params.join("&")
      end
    end
  end
end
