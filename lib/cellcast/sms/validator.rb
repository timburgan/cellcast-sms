# frozen_string_literal: true

module Cellcast
  module SMS
    # Common validation utilities to reduce code duplication
    # Provides reusable validation methods following DRY principle
    module Validator
      # Validate phone number format and content
      def validate_phone_number(phone)
        raise ValidationError, "Phone number cannot be nil or empty" if phone.nil? || phone.strip.empty?
        raise ValidationError, "Phone number must be a string" unless phone.is_a?(String)
      end

      # Validate SMS message content and length
      def validate_message(message)
        raise ValidationError, "Message cannot be nil or empty" if message.nil? || message.strip.empty?
        raise ValidationError, "Message must be a string" unless message.is_a?(String)
        raise ValidationError, "Message too long (max 1600 characters)" if message.length > 1600
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
        raise ValidationError, "URL cannot be nil or empty" if url.nil? || url.strip.empty?
        raise ValidationError, "URL must be a string" unless url.is_a?(String)
        
        begin
          uri = URI.parse(url)
          raise ValidationError, "URL must be HTTP or HTTPS" unless %w[http https].include?(uri.scheme)
        rescue URI::InvalidURIError
          raise ValidationError, "Invalid URL format"
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
        unless invalid_events.empty?
          raise ValidationError, "Invalid events: #{invalid_events.join(', ')}"
        end
      end
    end
  end
end