# frozen_string_literal: true

require "time"

module Cellcast
  module SMS
    # Handles sandbox mode mock responses
    # Provides realistic responses without making actual API calls
    class SandboxHandler
      # Special test numbers that trigger specific behaviors
      SANDBOX_TEST_NUMBERS = {
        "+15550000000" => :success,
        "+15550000001" => :failed,
        "+15550000002" => :rate_limited,
        "+15550000003" => :invalid_number,
        "+15550000004" => :insufficient_credits,
      }.freeze

      def initialize(logger: nil, base_url: "https://cellcast.com.au/api/v3")
        @logger = logger
        @base_url = base_url.chomp("/")
      end

      # Handle sandbox requests based on method and path
      def handle_request(method:, path:, body: nil)
        @current_path = path  # Store current path for error reporting
        log_sandbox_request(method, path, body) if @logger

        case path
        when "send-sms"
          handle_send_message(body)
        when "bulk-send-sms"
          handle_bulk_send_message(body)
        when /^get-sms\?message_id=(.+)/
          handle_get_message(Regexp.last_match(1))
        when /^get-responses\?(.+)/
          handle_get_responses(Regexp.last_match(1))
        when "send-sms-nz"
          handle_send_message_nz(body)
        when "send-sms-template"
          handle_send_template_message(body)
        when "inbound-read"
          handle_mark_inbound_read(body)
        when "inbound-read-bulk"
          handle_mark_inbound_read_bulk(body)
        when "register-alpha-id"
          handle_alpha_id_registration(body)
        when "account"
          handle_account_balance
        when "get-template"
          handle_get_templates
        when "get-optout"
          handle_get_optout_list
        # Legacy endpoints for backward compatibility (old tests)
        when %r{^api/v1/gateway$}
          handle_send_message(body)
        when %r{^api/v1/gateway/messages/(.+)$}
          handle_delete_message(::Regexp.last_match(1), method)
        when %r{^api/v1/business/add$}
          handle_business_name_registration(body)
        when %r{^api/v1/customNumber/add$}
          handle_custom_number_registration(body)
        when %r{^api/v1/customNumber/verifyCustomNumber$}
          handle_custom_number_verification(body)
        when %r{^api/v1/apiClient/account$}
          handle_account_balance
        when %r{^api/v2/report/message/quick-api-credit-usage$}
          handle_usage_report
        when %r{^api/v1/user/token/verify$}
          handle_token_verification
        else
          handle_unknown_endpoint(path)
        end
      end

      private

      def handle_send_message(body)
        # Official API uses sms_text and numbers array
        sms_text = body&.dig("sms_text") || body&.dig(:sms_text) || "Test message"
        numbers = body&.dig("numbers") || body&.dig(:numbers)
        
        # Handle array of numbers (official API format)
        if numbers.is_a?(Array)
          return handle_multiple_numbers(numbers, sms_text)
        end
        
        # Handle legacy single contact format for backward compatibility
        phone_number = body&.dig("to") || body&.dig(:to) || numbers
        
        # Single message handling
        behavior = SANDBOX_TEST_NUMBERS[phone_number] || :success

        case behavior
        when :success
          success_send_response(phone_number, sms_text)
        when :failed
          failed_send_response(phone_number)
        when :rate_limited
          rate_limit_error
        when :invalid_number
          invalid_number_error(phone_number)
        when :insufficient_credits
          insufficient_credits_error
        else
          success_send_response(phone_number, sms_text)
        end
      end

      # Handle multiple numbers array from official API format
      def handle_multiple_numbers(numbers, sms_text)
        valid_messages = []
        invalid_contacts = []
        
        numbers.each do |phone_number|
          behavior = SANDBOX_TEST_NUMBERS[phone_number] || :success
          
          case behavior
          when :success
            valid_messages << {
              "message_id" => generate_message_id,
              "from" => "TestSender", 
              "to" => phone_number,
              "body" => sms_text,
              "date" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
              "custom_string" => "",
              "direction" => "out"
            }
          when :invalid_number, :failed
            invalid_contacts << phone_number
          when :rate_limited
            return rate_limit_error
          when :insufficient_credits
            return insufficient_credits_error
          end
        end
        
        # If ALL numbers failed, return a failure response
        if valid_messages.empty? && !invalid_contacts.empty?
          return {
            "meta" => {
              "code" => 400,
              "status" => "FAILED"
            },
            "msg" => "Message failed to send",
            "data" => []
          }
        end
        
        # Return official API format for multiple recipients
        {
          "meta" => {
            "code" => 200, 
            "status" => "SUCCESS"
          },
          "msg" => "Queued",
          "data" => {
            "messages" => valid_messages,
            "total_numbers" => numbers.length,
            "success_number" => valid_messages.length,
            "credits_used" => valid_messages.length
          }
        }
      end

      # Handle bulk SMS sending (official API endpoint: bulk-send-sms)
      def handle_bulk_send_message(body)
        handle_send_message(body) # Reuse existing logic for now
      end

      # Handle get SMS message (official API endpoint: get-sms)
      def handle_get_message(message_id)
        {
          "meta" => { "code" => 200, "status" => "SUCCESS" },
          "msg" => "Record founded",
          "data" => [
            {
              "to" => "+61400000000",
              "body" => "Test message content",
              "sent_time" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
              "message_id" => message_id,
              "status" => "Delivered",
              "subaccount_id" => ""
            }
          ]
        }
      end

      # Handle get responses (official API endpoint: get-responses)
      def handle_get_responses(query_string)
        {
          "meta" => { "code" => 200, "status" => "SUCCESS" },
          "msg" => "You have 0 response(s)",
          "data" => {
            "page" => { "count" => 0, "number" => 1 },
            "total" => "0",
            "responses" => []
          }
        }
      end

      # Handle send NZ SMS (official API endpoint: send-sms-nz)
      def handle_send_message_nz(body)
        handle_send_message(body) # Reuse existing logic
      end

      # Handle send template message (official API endpoint: send-sms-template)
      def handle_send_template_message(body)
        {
          "meta" => { "code" => 200, "status" => "SUCCESS" },
          "msg" => "Queued",
          "data" => {
            "messages" => [
              {
                "message_id" => generate_message_id,
                "from" => "TestSender",
                "to" => "+61400000000",
                "body" => "Template message",
                "date" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
                "custom_string" => "",
                "direction" => "out"
              }
            ],
            "total_numbers" => 1,
            "success_number" => 1,
            "credits_used" => 1
          }
        }
      end

      # Handle mark inbound read (official API endpoint: inbound-read)
      def handle_mark_inbound_read(body)
        {
          "meta" => { "code" => 200, "status" => "SUCCESS" },
          "msg" => "Message marked as read",
          "data" => []
        }
      end

      # Handle mark inbound read bulk (official API endpoint: inbound-read-bulk)
      def handle_mark_inbound_read_bulk(body)
        {
          "meta" => { "code" => 200, "status" => "SUCCESS" },
          "msg" => "Messages marked as read",
          "data" => []
        }
      end

      # Handle get templates (official API endpoint: get-template)
      def handle_get_templates
        {
          "meta" => { "code" => 200, "status" => "SUCCESS" },
          "msg" => "Templates retrieved",
          "data" => []
        }
      end

      # Handle get optout list (official API endpoint: get-optout)
      def handle_get_optout_list
        {
          "meta" => { "code" => 200, "status" => "SUCCESS" },
          "msg" => "Optout list retrieved",
          "data" => []
        }
      end

      # Handle Alpha ID registration (official API endpoint: register-alpha-id)
      def handle_alpha_id_registration(body)
        {
          "meta" => { "code" => 200, "status" => "SUCCESS" },
          "msg" => "Alpha ID is successfully registered! Please check portal for Alpha ID status",
          "data" => []
        }
      end

      def handle_bulk_messages(messages, _body)
        valid_responses = []
        invalid_contacts = []

        messages.each do |msg|
          phone_number = msg["to"] || msg[:to]
          behavior = SANDBOX_TEST_NUMBERS[phone_number] || :success

          case behavior
          when :success
            message_id = generate_message_id
            contact_clean = phone_number&.gsub(/^\+/, "")&.gsub(/^61/, "")&.gsub(/^0/, "") || "400000000"
            valid_responses << {
              "Contact" => contact_clean,
              "MessageId" => message_id,
              "Result" => "Message added to queue.",
              "Number" => phone_number,
            }
          when :failed, :invalid_number
            invalid_contacts << phone_number
          end
        end

        {
          "app_type" => "web",
          "app_version" => "1.0",
          "maintainence" => 0,
          "new_version" => 0,
          "force_update" => 0,
          "invalid_token" => 0,
          "refresh_token" => "",
          "show_message" => 0,
          "is_enc" => false,
          "status" => true,
          "message" => "Request is being processed",
          "message_type" => "toast",
          "data" => {
            "queueResponse" => valid_responses,
            "message" => "success register all valid contacts to queue",
            "invalidContacts" => invalid_contacts,
            "unsubscribeContacts" => [],
            "totalValidContact" => valid_responses.length,
            "totalInvalidContact" => invalid_contacts.length,
            "totalUnsubscribeContact" => 0,
          },
          "error" => {},
        }
      end

      def handle_bulk_contacts(contacts, _body)
        valid_responses = []
        invalid_contacts = []

        contacts.each do |contact|
          behavior = SANDBOX_TEST_NUMBERS[contact] || :success

          case behavior
          when :success
            message_id = generate_message_id
            contact_clean = contact&.gsub(/^\+/, "")&.gsub(/^61/, "")&.gsub(/^0/, "") || "400000000"
            valid_responses << {
              "Contact" => contact_clean,
              "MessageId" => message_id,
              "Result" => "Message added to queue.",
              "Number" => contact,
            }
          when :failed, :invalid_number
            invalid_contacts << contact
          end
        end

        {
          "app_type" => "web",
          "app_version" => "1.0",
          "maintainence" => 0,
          "new_version" => 0,
          "force_update" => 0,
          "invalid_token" => 0,
          "refresh_token" => "",
          "show_message" => 0,
          "is_enc" => false,
          "status" => true,
          "message" => "Request is being processed",
          "message_type" => "toast",
          "data" => {
            "queueResponse" => valid_responses,
            "message" => "success register all valid contacts to queue",
            "invalidContacts" => invalid_contacts,
            "unsubscribeContacts" => [],
            "totalValidContact" => valid_responses.length,
            "totalInvalidContact" => invalid_contacts.length,
            "totalUnsubscribeContact" => 0,
          },
          "error" => {},
        }
      end

      def handle_business_name_registration(body)
        {
          "app_type" => "web",
          "app_version" => "1.0",
          "maintainence" => 0,
          "new_version" => 0,
          "force_update" => 0,
          "invalid_token" => 0,
          "refresh_token" => "",
          "show_message" => 0,
          "is_enc" => false,
          "status" => true,
          "message" => "Business name registered successfully!",
          "message_type" => "toast",
          "data" => {
            "business_id" => "sandbox_business_001",
            "business_name" => body&.dig("business_name") || body&.dig(:business_name),
            "status" => "pending_approval",
            "created_at" => Time.now.utc.iso8601,
          },
          "error" => {},
        }
      end

      def handle_custom_number_registration(body)
        {
          "app_type" => "web",
          "app_version" => "1.0",
          "maintainence" => 0,
          "new_version" => 0,
          "force_update" => 0,
          "invalid_token" => 0,
          "refresh_token" => "",
          "show_message" => 0,
          "is_enc" => false,
          "status" => true,
          "message" => "Custom number registered successfully! Please verify with OTP.",
          "message_type" => "toast",
          "data" => {
            "number_id" => "sandbox_number_001",
            "phone_number" => body&.dig("phone_number") || body&.dig(:phone_number),
            "status" => "pending_verification",
            "verification_required" => true,
            "created_at" => Time.now.utc.iso8601,
          },
          "error" => {},
        }
      end

      def handle_custom_number_verification(body)
        verification_code = body&.dig("verification_code") || body&.dig(:verification_code)

        if verification_code.nil? || verification_code.empty?
          {
            "app_type" => "web",
            "app_version" => "1.0",
            "maintainence" => 0,
            "new_version" => 0,
            "force_update" => 0,
            "invalid_token" => 0,
            "refresh_token" => "",
            "show_message" => 1,
            "is_enc" => false,
            "status" => false,
            "message_type" => "toast",
            "message" => "Verification code is required",
            "data" => {},
            "error" => {
              "error" => "Verification code is required",
            },
          }
        else
          {
            "app_type" => "web",
            "app_version" => "1.0",
            "maintainence" => 0,
            "new_version" => 0,
            "force_update" => 0,
            "invalid_token" => 0,
            "refresh_token" => "",
            "show_message" => 0,
            "is_enc" => false,
            "status" => true,
            "message" => "Custom number verified successfully!",
            "message_type" => "toast",
            "data" => {
              "phone_number" => body&.dig("phone_number") || body&.dig(:phone_number),
              "status" => "verified",
              "verified_at" => Time.now.utc.iso8601,
            },
            "error" => {},
          }
        end
      end

      def handle_account_balance
        {
          "meta" => { "code" => 200, "status" => "SUCCESS" },
          "msg" => "Here's your account",
          "data" => {
            "account_name" => "John Doe",
            "account_email" => "john@example.com",
            "sms_balance" => "125.50",
            "mms_balance" => "50.00"
          }
        }
      end

      def handle_usage_report
        {
          "app_type" => "web",
          "app_version" => "1.0",
          "maintainence" => 0,
          "new_version" => 0,
          "force_update" => 0,
          "invalid_token" => 0,
          "refresh_token" => "",
          "show_message" => 0,
          "is_enc" => false,
          "status" => true,
          "message" => "Usage report retrieved successfully!",
          "message_type" => "toast",
          "data" => {
            "period" => "quick-api-credit-usage",
            "total_messages" => 1456,
            "total_cost" => 87.36,
            "messages_this_month" => 234,
            "cost_this_month" => 14.04,
            "average_cost_per_message" => 0.06,
            "last_updated" => Time.now.utc.iso8601,
          },
          "error" => {},
        }
      end

      def handle_token_verification
        {
          "app_type" => "web",
          "app_version" => "1.0",
          "maintainence" => 0,
          "new_version" => 0,
          "force_update" => 0,
          "invalid_token" => 0,
          "refresh_token" => "",
          "show_message" => 0,
          "is_enc" => false,
          "status" => true,
          "message" => "Token verified successfully!",
          "message_type" => "toast",
          "data" => {
            "token" => "sandbox_api_key",
            "valid" => true,
            "verified_at" => Time.now.utc.iso8601,
          },
          "error" => {},
        }
      end

      def handle_generic_success
        {
          "success" => true,
          "sandbox_mode" => true,
          "timestamp" => Time.now.utc.iso8601,
        }
      end

      # Response builders
      def success_send_response(phone_number, sms_text = "Test message")
        message_id = generate_message_id
        
        # Official API response format from documentation
        {
          "meta" => {
            "code" => 200,
            "status" => "SUCCESS"
          },
          "msg" => "Queued",
          "data" => {
            "messages" => [
              {
                "message_id" => message_id,
                "from" => "TestSender",
                "to" => phone_number,
                "body" => sms_text,
                "date" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
                "custom_string" => "",
                "direction" => "out"
              }
            ],
            "total_numbers" => 1,
            "success_number" => 1,
            "credits_used" => 1
          }
        }
      end

      def failed_send_response(phone_number, bulk: false)
        # Official API error response format
        {
          "meta" => {
            "code" => 400,
            "status" => "FAILED"
          },
          "msg" => "Message failed to send",
          "data" => []
        }
      end

      def invalid_number_send_response(phone_number, bulk: false)
        {
          "app_type" => "web",
          "app_version" => "1.0",
          "maintainence" => 0,
          "new_version" => 0,
          "force_update" => 0,
          "invalid_token" => 0,
          "refresh_token" => "",
          "show_message" => 0,
          "is_enc" => false,
          "status" => false,
          "message" => "Invalid contact format",
          "message_type" => "toast",
          "data" => {
            "queueResponse" => [],
            "message" => "invalid contact format detected",
            "invalidContacts" => [phone_number],
            "unsubscribeContacts" => [],
            "totalValidContact" => 0,
            "totalInvalidContact" => 1,
            "totalUnsubscribeContact" => 0,
          },
          "error" => {
            "errorMessage" => "Invalid destination number",
          },
        }
      end

      # Error responses that raise exceptions
      def rate_limit_error
        # Create response body that matches official API error format
        error_response = {
          "app_type" => "web",
          "app_version" => "1.0",
          "maintainence" => 0,
          "new_version" => 0,
          "force_update" => 0,
          "invalid_token" => 0,
          "refresh_token" => "",
          "show_message" => 1,
          "is_enc" => false,
          "status" => false,
          "message_type" => "toast",
          "message" => "Rate limit exceeded in sandbox mode",
          "data" => {},
          "error" => {
            "errorMessage" => "Rate limit exceeded in sandbox mode",
          },
        }

        raise RateLimitError.new(
          "Rate limit exceeded in sandbox mode",
          status_code: 429,
          response_body: error_response.to_json,
          requested_url: build_full_url(@current_path),
          retry_after: 60
        )
      end

      def invalid_number_error(phone_number)
        # Use ValidationError with message that matches both official API validation messages and test expectations
        message = "Invalid phone number format: #{phone_number}. Contacts must either start with 61 or +61 and be exactly 11 digits long (e.g., 614xxxxxxxx or +614xxxxxxxx), or be 9 digits without the area code (e.g., 4xxxxxxxx)"
        raise ValidationError, "#{message} (sandbox mode: #{phone_number})"
      end

      def insufficient_credits_error
        # Create response body that matches official API error format
        error_response = {
          "app_type" => "web",
          "app_version" => "1.0",
          "maintainence" => 0,
          "new_version" => 0,
          "force_update" => 0,
          "invalid_token" => 0,
          "refresh_token" => "",
          "show_message" => 0,
          "is_enc" => false,
          "status" => false,
          "message_type" => "toast",
          "message" => "Your balance is too low for this request, please recharge.",
          "data" => {},
          "error" => {
            "errorMessage" => "Your balance is too low for this request, please recharge.",
          },
        }

        raise APIError.new(
          "Insufficient credits (sandbox mode)",
          status_code: 422,
          response_body: error_response.to_json,
          requested_url: build_full_url(@current_path)
        )
      end

      def handle_delete_message(message_id, method)
        # Only handle DELETE requests
        unless method.to_s.upcase == "DELETE"
          return handle_generic_success
        end

        # Special sandbox message IDs that trigger different behaviors
        case message_id
        when /^sandbox_fail_/
          delete_failed_response(message_id)
        when /^sandbox_notfound_/
          delete_not_found_response(message_id)
        when /^sandbox_already_sent_/
          delete_already_sent_response(message_id)
        else
          delete_success_response(message_id)
        end
      end

      def delete_success_response(message_id)
        {
          "app_type" => "web",
          "app_version" => "1.0",
          "maintainence" => 0,
          "new_version" => 0,
          "force_update" => 0,
          "invalid_token" => 0,
          "refresh_token" => "",
          "show_message" => 0,
          "is_enc" => false,
          "status" => true,
          "message" => "Message deleted successfully",
          "message_type" => "toast",
          "data" => {
            "message_id" => message_id,
            "deleted" => true,
            "deleted_at" => Time.now.utc.iso8601,
          },
          "error" => {},
        }
      end

      def delete_not_found_response(message_id)
        error_response = {
          "app_type" => "web",
          "app_version" => "1.0",
          "maintainence" => 0,
          "new_version" => 0,
          "force_update" => 0,
          "invalid_token" => 0,
          "refresh_token" => "",
          "show_message" => 1,
          "is_enc" => false,
          "status" => false,
          "message" => "Message not found",
          "message_type" => "toast",
          "data" => {},
          "error" => {
            "errorMessage" => "Message not found or already deleted",
          },
        }

        raise APIError.new(
          "Message not found (sandbox mode)",
          status_code: 404,
          response_body: error_response.to_json,
          requested_url: build_full_url(@current_path)
        )
      end

      def delete_already_sent_response(message_id)
        error_response = {
          "app_type" => "web",
          "app_version" => "1.0",
          "maintainence" => 0,
          "new_version" => 0,
          "force_update" => 0,
          "invalid_token" => 0,
          "refresh_token" => "",
          "show_message" => 1,
          "is_enc" => false,
          "status" => false,
          "message" => "Cannot delete message that has already been sent",
          "message_type" => "toast",
          "data" => {},
          "error" => {
            "errorMessage" => "Message has already been sent and cannot be deleted",
          },
        }

        raise APIError.new(
          "Cannot delete already sent message (sandbox mode)",
          status_code: 400,
          response_body: error_response.to_json,
          requested_url: build_full_url(@current_path)
        )
      end

      def delete_failed_response(message_id)
        error_response = {
          "app_type" => "web",
          "app_version" => "1.0",
          "maintainence" => 0,
          "new_version" => 0,
          "force_update" => 0,
          "invalid_token" => 0,
          "refresh_token" => "",
          "show_message" => 1,
          "is_enc" => false,
          "status" => false,
          "message" => "Failed to delete message",
          "message_type" => "toast",
          "data" => {},
          "error" => {
            "errorMessage" => "Internal server error while deleting message",
          },
        }

        raise APIError.new(
          "Delete operation failed (sandbox mode)",
          status_code: 500,
          response_body: error_response.to_json,
          requested_url: build_full_url(@current_path)
        )
      end

      def generate_message_id
        "sandbox_#{Time.now.to_i}_#{rand(1000..9999)}"
      end

      def handle_unknown_endpoint(path)
        error_response = {
          "app_type" => "web",
          "app_version" => "1.0",
          "maintainence" => 0,
          "new_version" => 0,
          "force_update" => 0,
          "invalid_token" => 0,
          "refresh_token" => "",
          "show_message" => 1,
          "is_enc" => false,
          "status" => false,
          "message" => "Endpoint not found",
          "message_type" => "toast",
          "data" => {},
          "error" => {
            "errorMessage" => "The endpoint '#{path}' is not supported or does not exist",
          },
        }

        raise APIError.new(
          "Endpoint not found: #{path} (sandbox mode)",
          status_code: 404,
          response_body: error_response.to_json,
          requested_url: build_full_url(path)
        )
      end

      def log_sandbox_request(method, path, body)
        @logger.info("Sandbox request: #{method.upcase} #{path}")
        @logger.debug("Sandbox request body: #{body}") if body
      end

      def build_full_url(path)
        return "#{@base_url}/#{path.gsub(%r{^/}, '')}" if path
        @base_url
      end
    end
  end
end
