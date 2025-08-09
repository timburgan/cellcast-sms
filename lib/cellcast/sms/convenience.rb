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

      # Cancel a scheduled SMS message
      # This is primarily used to cancel scheduled messages that haven't been sent yet
      # @param message_id [String] The message ID to cancel
      # @return [Response] Wrapped response confirming cancellation
      def cancel_message(message_id:)
        response = sms.delete_message(message_id: message_id)
        Response.new(response)
      end

      # Verify your API token
      # @return [Response] Token verification response
      def verify_token
        response = token.verify_token
        Response.new(response)
      end

      # Get account balance
      # @return [Response] Account balance response
      def balance
        response = account.get_account_balance
        Response.new(response)
      end

      # Get usage report
      # @return [Response] Usage statistics response
      def usage_report
        response = account.get_usage_report
        Response.new(response)
      end

      # Register a business name for sender ID
      # @param business_name [String] The business name
      # @param business_registration [String] Business registration details
      # @param contact_info [Hash] Contact information
      # @return [Response] Registration response
      def register_business(business_name:, business_registration:, contact_info:)
        response = sender_id.register_business_name(
          business_name: business_name,
          business_registration: business_registration,
          contact_info: contact_info
        )
        Response.new(response)
      end

      # Register a custom number for sender ID
      # @param phone_number [String] The phone number
      # @param purpose [String] Purpose for the number
      # @return [Response] Registration response
      def register_number(phone_number:, purpose:)
        response = sender_id.register_custom_number(
          phone_number: phone_number,
          purpose: purpose
        )
        Response.new(response)
      end

      # Verify a custom number
      # @param phone_number [String] The phone number
      # @param verification_code [String] The verification code
      # @return [Response] Verification response
      def verify_number(phone_number:, verification_code:)
        response = sender_id.verify_custom_number(
          phone_number: phone_number,
          verification_code: verification_code
        )
        Response.new(response)
      end
    end
  end
end
