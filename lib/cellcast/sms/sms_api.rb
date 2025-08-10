# frozen_string_literal: true

module Cellcast
  module SMS
    # SMS API endpoints implementation - based on official Cellcast API documentation
    # Base URL: https://cellcast.com.au/api/v3/
    # Authentication: APPKEY header
    class SMSApi
      include Validator

      def initialize(client)
        @client = client
      end

      # Send a single SMS message
      # Official endpoint: POST https://cellcast.com.au/api/v3/send-sms
      # @param to [String] The recipient phone number
      # @param message [String] The SMS message content
      # @param sender_id [String, nil] Optional sender ID
      # @param options [Hash] Additional options (custom_string, schedule_time, delay)
      # @return [Hash] API response with meta, msg, data structure
      def send_message(to:, message:, sender_id: nil, **options)
        validate_phone_number(to)
        validate_message(message)

        body = build_send_message_body([to], message, sender_id, options)
        @client.request(method: :post, path: "send-sms", body: body)
      end

      # Send bulk SMS messages
      # Official endpoint: POST https://cellcast.com.au/api/v3/bulk-send-sms
      # @param messages [Array<Hash>] Array of message hashes with :to, :message, and optional :sender_id
      # @param options [Hash] Additional options applied to all messages
      # @return [Hash] API response with meta, msg, data structure
      def send_bulk(messages:, **options)
        validate_bulk_messages(messages)

        body = build_bulk_message_body(messages, options)
        @client.request(method: :post, path: "bulk-send-sms", body: body)
      end

      # Get SMS message details by message ID
      # Official endpoint: GET https://cellcast.com.au/api/v3/get-sms?message_id=<id>
      # @param message_id [String] The message ID to retrieve
      # @return [Hash] API response with message details
      def get_message(message_id:)
        validate_message_id(message_id)
        @client.request(method: :get, path: "get-sms?message_id=#{message_id}")
      end

      # Get inbound messages/responses
      # Official endpoint: GET https://cellcast.com.au/api/v3/get-responses?page=<page>&type=sms
      # @param page [Integer] Page number for pagination (default: 1)
      # @param type [String] Message type, typically 'sms' (default: 'sms')
      # @return [Hash] API response with inbound messages
      def get_responses(page: 1, type: 'sms')
        @client.request(method: :get, path: "get-responses?page=#{page}&type=#{type}")
      end

      # Send SMS to New Zealand numbers
      # Official endpoint: POST https://cellcast.com.au/api/v3/send-sms-nz
      # @param to [String] The NZ recipient phone number
      # @param message [String] The SMS message content
      # @param sender_id [String, nil] Optional sender ID
      # @param options [Hash] Additional options
      # @return [Hash] API response
      def send_message_nz(to:, message:, sender_id: nil, **options)
        validate_phone_number(to)
        validate_message(message)

        body = build_send_message_body([to], message, sender_id, options)
        @client.request(method: :post, path: "send-sms-nz", body: body)
      end

      # Send SMS using a template
      # Official endpoint: POST https://cellcast.com.au/api/v3/send-sms-template
      # @param template_id [String] The template ID to use
      # @param numbers [Array] Array of recipient objects with number and personalization data
      # @param sender_id [String, nil] Optional sender ID
      # @param options [Hash] Additional options
      # @return [Hash] API response
      def send_message_template(template_id:, numbers:, sender_id: nil, **options)
        validate_template_id(template_id)
        validate_template_numbers(numbers)

        body = {
          template_id: template_id,
          numbers: numbers,
        }

        body[:sender_id] = sender_id if sender_id
        body[:custom_string] = options[:custom_string] if options[:custom_string]
        body[:schedule_time] = options[:schedule_time] if options[:schedule_time]
        body[:delay] = options[:delay] if options[:delay]

        @client.request(method: :post, path: "send-sms-template", body: body)
      end

      # Mark inbound messages as read
      # Official endpoint: POST https://cellcast.com.au/api/v3/inbound-read
      # @param message_id [String] The inbound message ID to mark as read
      # @return [Hash] API response
      def mark_inbound_read(message_id:)
        validate_message_id(message_id)
        
        body = { message_id: message_id }
        @client.request(method: :post, path: "inbound-read", body: body)
      end

      # Mark multiple inbound messages as read
      # Official endpoint: POST https://cellcast.com.au/api/v3/inbound-read-bulk
      # @param timestamp [String, nil] Optional timestamp to mark all messages before this time as read
      # @return [Hash] API response
      def mark_inbound_read_bulk(timestamp: nil)
        body = {}
        body[:timestamp] = timestamp if timestamp
        
        @client.request(method: :post, path: "inbound-read-bulk", body: body)
      end

      private

      def validate_template_id(template_id)
        raise ValidationError, "Template ID cannot be nil or empty" if template_id.nil? || template_id.to_s.strip.empty?
      end

      def validate_template_numbers(numbers)
        raise ValidationError, "Numbers must be an array" unless numbers.is_a?(Array)
        raise ValidationError, "Numbers array cannot be empty" if numbers.empty?

        numbers.each_with_index do |number_data, index|
          raise ValidationError, "Number data at index #{index} must be a hash" unless number_data.is_a?(Hash)
          raise ValidationError, "Number data at index #{index} missing :number" unless number_data.key?(:number)
          validate_phone_number(number_data[:number])
        end
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

      def build_send_message_body(numbers, message, sender_id, options)
        body = {
          sms_text: message,
          numbers: numbers,
        }

        body[:sender_id] = sender_id if sender_id
        body[:custom_string] = options[:custom_string] if options[:custom_string]
        body[:schedule_time] = options[:schedule_time] if options[:schedule_time]
        body[:delay] = options[:delay] if options[:delay]

        body
      end

      def build_bulk_message_body(messages, options)
        # For bulk messages, we need to group by message content and sender_id
        # The API expects arrays of phone numbers for each unique message
        grouped_messages = messages.group_by { |msg| [msg[:message], msg[:sender_id]] }

        bulk_data = grouped_messages.map do |(message, sender_id), msgs|
          numbers = msgs.map { |m| m[:to] }
          body = {
            sms_text: message,
            numbers: numbers,
          }
          
          body[:sender_id] = sender_id if sender_id
          body[:custom_string] = options[:custom_string] if options[:custom_string]
          body[:schedule_time] = options[:schedule_time] if options[:schedule_time]
          body[:delay] = options[:delay] if options[:delay]
          
          body
        end

        # For bulk API, we send an array of message objects
        bulk_data.length == 1 ? bulk_data.first : bulk_data
      end
    end
  end
end
