# frozen_string_literal: true

module Cellcast
  module SMS
    # Convenience methods and simplified interface for common operations
    # Provides a more developer-friendly API while maintaining full flexibility
    # Based on official Cellcast API documentation
    module ConvenienceMethods
      # Send a quick SMS with minimal configuration
      # @param to [String] Phone number to send to
      # @param message [String] Message content
      # @param from [String, nil] Optional sender ID
      # @return [Hash] Raw API response with meta, msg, data structure
      def quick_send(to:, message:, from: nil)
        sms.send_message(to: to, message: message, sender_id: from)
      end

      # Send SMS to multiple recipients with the same message
      # @param to [Array<String>] Array of phone numbers
      # @param message [String] Message content
      # @param from [String, nil] Optional sender ID
      # @return [Hash] Raw API response with meta, msg, data structure
      def broadcast(to:, message:, from: nil)
        messages = to.map { |phone| { to: phone, message: message, sender_id: from }.compact }
        sms.send_bulk(messages: messages)
      end

      # Get SMS message status and details
      # @param message_id [String] The message ID to look up
      # @return [Hash] Raw API response with message details
      def get_message_status(message_id:)
        sms.get_message(message_id: message_id)
      end

      # Get inbound messages/responses
      # @param page [Integer] Page number for pagination (default: 1)
      # @return [Hash] Raw API response with inbound messages
      def get_inbound_messages(page: 1)
        sms.get_responses(page: page)
      end

      # Send SMS to New Zealand numbers
      # @param to [String] NZ phone number to send to
      # @param message [String] Message content
      # @param from [String, nil] Optional sender ID
      # @return [Hash] Raw API response
      def send_to_nz(to:, message:, from: nil)
        sms.send_message_nz(to: to, message: message, sender_id: from)
      end

      # Get account balance
      # @return [Hash] Raw account balance response with sms_balance, mms_balance
      def balance
        account.get_account_balance
      end

      # Get SMS templates
      # @return [Hash] Raw templates response
      def get_templates
        account.get_templates
      end

      # Get opt-out list
      # @return [Hash] Raw opt-out list response
      def get_optouts
        account.get_optout_list
      end

      # Register an Alpha ID (business name) for sender ID
      # @param alpha_id [String] The alpha ID/business name (max 11 characters)
      # @param purpose [String] Purpose for the alpha ID
      # @param business_registration [String, nil] Optional business registration details
      # @param contact_info [Hash, nil] Optional contact information
      # @return [Hash] Raw registration response
      def register_alpha_id(alpha_id:, purpose:, business_registration: nil, contact_info: nil)
        sender_id.register_alpha_id(
          alpha_id: alpha_id,
          purpose: purpose,
          business_registration: business_registration,
          contact_info: contact_info
        )
      end

      # Send SMS using a template
      # @param template_id [String] The template ID to use
      # @param numbers [Array] Array of recipient objects with number and personalization data
      # @param from [String, nil] Optional sender ID
      # @return [Hash] Raw API response
      def send_template(template_id:, numbers:, from: nil)
        sms.send_message_template(template_id: template_id, numbers: numbers, sender_id: from)
      end

      # Mark inbound messages as read
      # @param message_id [String] The inbound message ID to mark as read
      # @return [Hash] Raw API response
      def mark_read(message_id:)
        sms.mark_inbound_read(message_id: message_id)
      end

      # Mark all inbound messages as read
      # @param before [String, nil] Optional timestamp to mark messages before this time as read
      # @return [Hash] Raw API response
      def mark_all_read(before: nil)
        sms.mark_inbound_read_bulk(timestamp: before)
      end
    end
  end
end
