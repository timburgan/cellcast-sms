# frozen_string_literal: true

module Cellcast
  module SMS
    # Common validation utilities to reduce code duplication
    # Provides reusable validation methods following DRY principle
    module Validator
      # Validate phone number format and content
      def validate_phone_number(phone)
        raise ValidationError, "Phone number must be a string, got #{phone.class}" unless phone.is_a?(String)

        if phone.nil? || phone.strip.empty?
          raise ValidationError,
                "Phone number cannot be nil or empty. Please provide a valid phone number in international format (e.g., +1234567890)"
        end

        # Strip whitespace for validation
        clean_phone = phone.strip

        # Basic format validation for international numbers
        unless clean_phone.match?(/^\+[1-9]\d{4,14}$/)
          raise ValidationError,
                "Invalid phone number format: #{phone}. Please use international format (e.g., +1234567890)"
        end
      end

      # Validate SMS message content and length
      def validate_message(message)
        raise ValidationError, "Message must be a string, got #{message.class}" unless message.is_a?(String)

        if message.nil? || message.strip.empty?
          raise ValidationError, "Message cannot be nil or empty. Please provide message content."
        end

        if message.length > 1600
          raise ValidationError,
                "Message too long (#{message.length}/1600 characters). Consider splitting into multiple messages."
        end
      end

      # Validate message ID format
      def validate_message_id(message_id)
        raise ValidationError, "Message ID cannot be nil or empty" if message_id.nil? || message_id.strip.empty?
        raise ValidationError, "Message ID must be a string" unless message_id.is_a?(String)
      end

      # Validate array of message IDs
      def validate_message_ids(message_ids)
        raise ValidationError, "Message IDs must be an array" unless message_ids.is_a?(Array)
        raise ValidationError, "Message IDs array cannot be empty" if message_ids.empty?
        raise ValidationError, "Too many message IDs (max 100)" if message_ids.length > 100

        message_ids.each_with_index do |id, index|
          raise ValidationError, "Message ID at index #{index} cannot be nil or empty" if id.nil? || id.strip.empty?
          raise ValidationError, "Message ID at index #{index} must be a string" unless id.is_a?(String)
        end
      end

      # Validate pagination parameters
      def validate_pagination_params(limit, offset)
        raise ValidationError, "Limit must be between 1 and 100" unless (1..100).cover?(limit)
        raise ValidationError, "Offset must be non-negative" unless offset >= 0
      end

      # Validate URL format
      def validate_url(url)
        if url.nil? || url.strip.empty?
          raise ValidationError, "URL cannot be nil or empty. Please provide a valid HTTP or HTTPS URL."
        end
        raise ValidationError, "URL must be a string, got #{url.class}" unless url.is_a?(String)

        begin
          uri = URI.parse(url)
          unless %w[http https].include?(uri.scheme)
            raise ValidationError, "URL must be HTTP or HTTPS, got #{uri.scheme}. Example: https://yourapp.com/webhooks"
          end
        rescue URI::InvalidURIError => e
          raise ValidationError, "Invalid URL format: #{e.message}. Please provide a valid URL like https://yourapp.com/webhooks"
        end
      end

      # Validate event types for webhooks
      def validate_events(events)
        raise ValidationError, "Events must be an array" unless events.is_a?(Array)
        raise ValidationError, "Events array cannot be empty" if events.empty?

        valid_events = %w[
          sms.sent sms.delivered sms.failed
          sms.received sms.reply
          sender_id.approved sender_id.rejected
          token.expired test
        ]

        invalid_events = events - valid_events
        raise ValidationError, "Invalid events: #{invalid_events.join(', ')}" unless invalid_events.empty?
      end
    end
  end
end
