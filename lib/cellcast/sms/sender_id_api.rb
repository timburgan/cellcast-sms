# frozen_string_literal: true

module Cellcast
  module SMS
    # Sender ID API endpoints implementation - based on official Cellcast API documentation
    # Base URL: https://cellcast.com.au/api/v3/
    class SenderIdApi
      include Validator

      def initialize(client)
        @client = client
      end

      # Register an Alpha ID (business name)
      # Official endpoint: POST https://www.cellcast.com.au/api/v3/register-alpha-id
      # @param alpha_id [String] The alpha ID/business name to register
      # @param purpose [String] Purpose for the alpha ID
      # @param business_registration [String] Business registration details
      # @param contact_info [Hash] Contact information
      # @return [Hash] API response
      def register_alpha_id(alpha_id:, purpose:, business_registration: nil, contact_info: nil)
        validate_alpha_id(alpha_id)
        validate_purpose(purpose)

        body = {
          alpha_id: alpha_id,
          purpose: purpose,
        }

        body[:business_registration] = business_registration if business_registration
        body[:contact_info] = contact_info if contact_info

        @client.request(method: :post, path: "register-alpha-id", body: body)
      end

      private

      def validate_alpha_id(alpha_id)
        raise ValidationError, "Alpha ID cannot be nil or empty" if alpha_id.nil? || alpha_id.strip.empty?
        raise ValidationError, "Alpha ID must be a string" unless alpha_id.is_a?(String)
        raise ValidationError, "Alpha ID too long (max 11 characters)" if alpha_id.length > 11
        raise ValidationError, "Alpha ID must only contain letters and numbers" unless alpha_id.match?(/\A[a-zA-Z0-9]+\z/)
      end

      def validate_purpose(purpose)
        raise ValidationError, "Purpose cannot be nil or empty" if purpose.nil? || purpose.strip.empty?
        raise ValidationError, "Purpose must be a string" unless purpose.is_a?(String)
      end
    end
  end
end
