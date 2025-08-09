# frozen_string_literal: true

module Cellcast
  module SMS
    # Business and Custom Number API endpoints implementation - only officially documented endpoints
    # Based on official Cellcast API documentation:
    # - POST api/v1/business/add (business name)
    # - POST api/v1/customNumber/add (custom number)
    # - POST api/v1/customNumber/verifyCustomNumber (verify custom number)
    class SenderIdApi
      def initialize(client)
        @client = client
      end

      # Register a business name
      # Official endpoint: POST https://api.cellcast.com/api/v1/business/add
      # @param business_name [String] The business name to register
      # @param business_registration [String] Business registration details
      # @param contact_info [Hash] Contact information
      # @return [Hash] API response
      def register_business_name(business_name:, business_registration:, contact_info:)
        validate_business_name(business_name)
        validate_business_registration(business_registration)
        validate_contact_info(contact_info)

        body = {
          business_name: business_name,
          business_registration: business_registration,
          contact_info: contact_info,
        }

        @client.request(method: :post, path: "api/v1/business/add", body: body)
      end

      # Register a custom number
      # Official endpoint: POST https://api.cellcast.com/api/v1/customNumber/add
      # @param phone_number [String] The phone number to register
      # @param purpose [String] Purpose for the custom number
      # @return [Hash] API response
      def register_custom_number(phone_number:, purpose:)
        validate_phone_number(phone_number)
        validate_purpose(purpose)

        body = {
          phone_number: phone_number,
          purpose: purpose,
        }

        @client.request(method: :post, path: "api/v1/customNumber/add", body: body)
      end

      # Verify a custom number
      # Official endpoint: POST https://api.cellcast.com/api/v1/customNumber/verifyCustomNumber
      # @param phone_number [String] The phone number to verify
      # @param verification_code [String] The verification code
      # @return [Hash] API response
      def verify_custom_number(phone_number:, verification_code:)
        validate_phone_number(phone_number)
        validate_verification_code(verification_code)

        body = {
          phone_number: phone_number,
          verification_code: verification_code,
        }

        @client.request(method: :post, path: "api/v1/customNumber/verifyCustomNumber", body: body)
      end

      private

      def validate_business_name(name)
        raise ValidationError, "Business name cannot be nil or empty" if name.nil? || name.strip.empty?
        raise ValidationError, "Business name must be a string" unless name.is_a?(String)
        raise ValidationError, "Business name too long (max 50 characters)" if name.length > 50
      end

      def validate_business_registration(registration)
        if registration.nil? || registration.strip.empty?
          raise ValidationError,
                "Business registration cannot be nil or empty"
        end
        raise ValidationError, "Business registration must be a string" unless registration.is_a?(String)
      end

      def validate_contact_info(contact_info)
        raise ValidationError, "Contact info must be a hash" unless contact_info.is_a?(Hash)
        raise ValidationError, "Contact info must include email" unless contact_info.key?(:email)
        raise ValidationError, "Contact info must include phone" unless contact_info.key?(:phone)
      end

      def validate_phone_number(phone)
        raise ValidationError, "Phone number cannot be nil or empty" if phone.nil? || phone.strip.empty?
        raise ValidationError, "Phone number must be a string" unless phone.is_a?(String)
      end

      def validate_purpose(purpose)
        raise ValidationError, "Purpose cannot be nil or empty" if purpose.nil? || purpose.strip.empty?
        raise ValidationError, "Purpose must be a string" unless purpose.is_a?(String)
      end

      def validate_verification_code(code)
        raise ValidationError, "Verification code cannot be nil or empty" if code.nil? || code.strip.empty?
        raise ValidationError, "Verification code must be a string" unless code.is_a?(String)
      end
    end
  end
end
