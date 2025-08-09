# frozen_string_literal: true

module Cellcast
  module SMS
    # Convenience methods and simplified interface for common operations
    # Provides a more developer-friendly API while maintaining full flexibility
    # Only includes methods for officially documented API endpoints
    module ConvenienceMethods
      # Send a quick SMS with minimal configuration
      # @param to [String] Phone number to send to
      # @param message [String] Message content
      # @param from [String, nil] Optional sender ID
      # @return [Hash] Raw API response
      def quick_send(to:, message:, from: nil)
        sms.send_message(to: to, message: message, sender_id: from)
      end

      # Send SMS to multiple recipients with the same message
      # @param to [Array<String>] Array of phone numbers
      # @param message [String] Message content
      # @param from [String, nil] Optional sender ID
      # @return [Hash] Raw API response
      def broadcast(to:, message:, from: nil)
        messages = to.map { |phone| { to: phone, message: message, sender_id: from }.compact }
        sms.send_bulk(messages: messages)
      end

      # Cancel a scheduled SMS message
      # This is primarily used to cancel scheduled messages that haven't been sent yet
      # @param message_id [String] The message ID to cancel
      # @return [Hash] Raw API response confirming cancellation
      def cancel_message(message_id:)
        sms.delete_message(message_id: message_id)
      end

      # Verify your API token
      # @return [Hash] Raw token verification response
      def verify_token
        token.verify_token
      end

      # Get account balance
      # @return [Hash] Raw account balance response
      def balance
        account.get_account_balance
      end

      # Get usage report
      # @return [Hash] Raw usage statistics response
      def usage_report
        account.get_usage_report
      end

      # Register a business name for sender ID
      # @param business_name [String] The business name
      # @param business_registration [String] Business registration details
      # @param contact_info [Hash] Contact information
      # @return [Hash] Raw registration response
      def register_business(business_name:, business_registration:, contact_info:)
        sender_id.register_business_name(
          business_name: business_name,
          business_registration: business_registration,
          contact_info: contact_info
        )
      end

      # Register a custom number for sender ID
      # @param phone_number [String] The phone number
      # @param purpose [String] Purpose for the number
      # @return [Hash] Raw registration response
      def register_number(phone_number:, purpose:)
        sender_id.register_custom_number(
          phone_number: phone_number,
          purpose: purpose
        )
      end

      # Verify a custom number
      # @param phone_number [String] The phone number
      # @param verification_code [String] The verification code
      # @return [Hash] Raw verification response
      def verify_number(phone_number:, verification_code:)
        sender_id.verify_custom_number(
          phone_number: phone_number,
          verification_code: verification_code
        )
      end
    end
  end
end
