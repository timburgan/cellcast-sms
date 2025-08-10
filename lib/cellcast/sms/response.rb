# frozen_string_literal: true

module Cellcast
  module SMS
    # Base response wrapper class providing common functionality
    class BaseResponse
      attr_reader :raw_response

      def initialize(raw_response)
        @raw_response = raw_response
      end

      # Check if the API call was successful
      def success?
        @raw_response.dig('meta', 'status') == 'SUCCESS'
      end

      # Check if the API call failed
      def error?
        !success?
      end

      # Get the API message
      def api_message
        @raw_response['msg']
      end

      # Get the HTTP status code
      def status_code
        @raw_response.dig('meta', 'code')
      end

      # Enable hash-like access for backward compatibility
      def [](key)
        @raw_response[key]
      end

      # Enable dig access for backward compatibility
      def dig(*keys)
        @raw_response.dig(*keys)
      end

      # Support iteration like a hash
      def each(&block)
        @raw_response.each(&block)
      end

      # Convert to hash (returns raw response)
      def to_h
        @raw_response
      end
      alias_method :to_hash, :to_h

      # String representation
      def to_s
        "#{self.class.name}(success: #{success?}, message: '#{api_message}')"
      end

      # Chainable success handler
      def on_success(&block)
        block.call(self) if success? && block_given?
        self
      end

      # Chainable error handler
      def on_error(&block)
        block.call(self) if error? && block_given?
        self
      end

      # Get low SMS balance alert if present
      def low_sms_alert
        @raw_response['low_sms_alert']
      end

      # Check if there's a low balance alert
      def low_balance_alert?
        !low_sms_alert.nil? && !low_sms_alert.empty?
      end
    end

    # Response wrapper for single SMS send operations
    class SendSmsResponse < BaseResponse
      # Get the message ID of the sent SMS
      def message_id
        @raw_response.dig('data', 'messages', 0, 'message_id')
      end

      # Get the number of credits used
      def credits_used
        @raw_response.dig('data', 'credits_used')
      end

      # Get the total number of recipients
      def total_numbers
        @raw_response.dig('data', 'total_numbers')
      end

      # Get the number of successful sends
      def success_number
        @raw_response.dig('data', 'success_number')
      end

      # Get all message details
      def messages
        @raw_response.dig('data', 'messages') || []
      end

      # Get the first (and usually only) message
      def message
        messages.first
      end

      # Get the recipient number
      def to
        message&.dig('to')
      end

      # Get the message content
      def message_text
        message&.dig('message')
      end

      # Get the sender ID used
      def from
        message&.dig('from')
      end

      # Check if all numbers were successful
      def all_successful?
        success? && success_number == total_numbers
      end
    end

    # Response wrapper for bulk SMS operations
    class BulkSmsResponse < BaseResponse
      # Get the number of credits used
      def credits_used
        @raw_response.dig('data', 'credits_used')
      end

      # Get the total number of recipients
      def total_numbers
        @raw_response.dig('data', 'total_numbers')
      end

      # Get the number of successful sends
      def success_number
        @raw_response.dig('data', 'success_number')
      end

      # Get the number of failed sends
      def failed_number
        total_numbers - success_number if total_numbers && success_number
      end

      # Get all message details
      def messages
        @raw_response.dig('data', 'messages') || []
      end

      # Iterate over each message
      def each_message
        return enum_for(:each_message) unless block_given?
        
        messages.each { |msg| yield(msg) }
      end

      # Check if all numbers were successful
      def all_successful?
        success? && success_number == total_numbers
      end

      # Check if there were any failures
      def has_failures?
        failed_number && failed_number > 0
      end

      # Get success rate as a percentage
      def success_rate
        return 0 unless total_numbers && total_numbers > 0
        (success_number.to_f / total_numbers * 100).round(2)
      end
    end

    # Response wrapper for account balance operations
    class AccountBalanceResponse < BaseResponse
      # Get SMS balance
      def sms_balance
        @raw_response.dig('data', 'sms_balance')
      end

      # Get MMS balance
      def mms_balance
        @raw_response.dig('data', 'mms_balance')
      end

      # Get account name
      def account_name
        @raw_response.dig('data', 'account_name')
      end

      # Check if SMS balance is low (configurable threshold)
      def low_sms_balance?(threshold = 10)
        return false unless sms_balance
        balance_val = sms_balance.is_a?(String) ? sms_balance.to_f : sms_balance
        balance_val < threshold
      end

      # Check if MMS balance is low (configurable threshold)
      def low_mms_balance?(threshold = 5)
        return false unless mms_balance
        balance_val = mms_balance.is_a?(String) ? mms_balance.to_f : mms_balance
        balance_val < threshold
      end

      # Check if any balance is low
      def low_balance?(sms_threshold = 10, mms_threshold = 5)
        low_sms_balance?(sms_threshold) || low_mms_balance?(mms_threshold)
      end

      # Get total balance (SMS + MMS)
      def total_balance
        sms_val = sms_balance.is_a?(String) ? sms_balance.to_f : (sms_balance || 0)
        mms_val = mms_balance.is_a?(String) ? mms_balance.to_f : (mms_balance || 0)
        sms_val + mms_val
      end
    end

    # Wrapper for individual inbound messages
    class InboundMessage
      def initialize(message_data)
        @data = message_data
      end

      # Get sender number
      def from
        @data['from']
      end

      # Get message content
      def body
        @data['body']
      end

      # Get message received timestamp
      def received_at
        return nil unless @data['received_date']
        Time.parse(@data['received_date'])
      rescue ArgumentError
        nil
      end

      # Get message ID
      def message_id
        @data['messageId']
      end

      # Check if message has been read
      def read?
        @data['read'] == '1' || @data['read'] == true
      end

      # Check if message is unread
      def unread?
        !read?
      end

      # Get raw message data
      def to_h
        @data
      end
      alias_method :to_hash, :to_h

      # Hash-like access
      def [](key)
        @data[key]
      end

      # String representation
      def to_s
        "InboundMessage(from: '#{from}', message: '#{body}', read: #{read?})"
      end
    end

    # Response wrapper for inbound messages operations
    class InboundMessagesResponse < BaseResponse
      # Get array of message data
      def messages_data
        @raw_response.dig('data', 'data') || []
      end

      # Get wrapped message objects
      def messages
        @messages ||= messages_data.map { |msg| InboundMessage.new(msg) }
      end

      # Iterate over each message
      def each_message
        return enum_for(:each_message) unless block_given?
        
        messages.each { |msg| yield(msg) }
      end

      # Get only unread messages
      def unread_messages
        messages.select(&:unread?)
      end

      # Get only read messages
      def read_messages
        messages.select(&:read?)
      end

      # Check if there are more pages
      def has_more_pages?
        current_page < total_pages
      end

      # Get current page number
      def current_page
        @raw_response.dig('data', 'current_page') || 1
      end

      # Get total number of pages
      def total_pages
        @raw_response.dig('data', 'last_page') || 1
      end

      # Get total number of messages across all pages
      def total_messages
        @raw_response.dig('data', 'total')
      end

      # Get messages per page
      def per_page
        @raw_response.dig('data', 'per_page')
      end

      # Check if this is the first page
      def first_page?
        current_page == 1
      end

      # Check if this is the last page
      def last_page?
        current_page >= total_pages
      end

      # Get the next page number (nil if no next page)
      def next_page
        has_more_pages? ? current_page + 1 : nil
      end

      # Get the previous page number (nil if no previous page)
      def previous_page
        current_page > 1 ? current_page - 1 : nil
      end

      # Get count of messages on current page
      def message_count
        messages.length
      end
    end

    # Response wrapper for message details/status operations
    class MessageDetailsResponse < BaseResponse
      # Get message details
      def message
        data = @raw_response.dig('data')
        # Handle both array and object formats from API
        if data.is_a?(Array)
          data.first
        else
          data.is_a?(Hash) ? data['message'] || data : nil
        end
      end

      # Get message ID
      def message_id
        message&.dig('message_id')
      end

      # Get message status
      def status
        message&.dig('status')
      end

      # Get recipient number
      def to
        message&.dig('to')
      end

      # Get message content
      def message_text
        message&.dig('message') || message&.dig('body')
      end

      # Get sender ID
      def from
        message&.dig('from')
      end

      # Get delivery timestamp
      def delivered_at
        date_field = message&.dig('delivered_date') || message&.dig('sent_time')
        return nil unless date_field
        Time.parse(date_field)
      rescue ArgumentError
        nil
      end

      # Check if message was delivered
      def delivered?
        status&.downcase == 'delivered'
      end

      # Check if message failed
      def failed?
        status&.downcase == 'failed'
      end

      # Check if message is pending
      def pending?
        status&.downcase == 'pending' || status&.downcase == 'queued'
      end
    end

    # Response wrapper for template operations
    class TemplatesResponse < BaseResponse
      # Get templates array
      def templates
        @raw_response['data'] || []
      end

      # Get template count
      def template_count
        templates.length
      end

      # Find template by ID or name
      def find_template(identifier)
        templates.find { |t| t['id'] == identifier || t['template_id'] == identifier || t['name'] == identifier }
      end

      # Get template names
      def template_names
        templates.map { |t| t['name'] }.compact
      end

      # Check if templates are available
      def has_templates?
        template_count > 0
      end
    end

    # Response wrapper for registration operations (Alpha ID, etc.)
    class RegistrationResponse < BaseResponse
      # Get registration details
      def registration
        @raw_response['data'] || {}
      end

      # Get registration ID if available
      def registration_id
        registration['id'] || registration['registration_id']
      end

      # Get registration status
      def registration_status
        registration['status']
      end

      # Check if registration is pending
      def pending?
        registration_status == 'pending'
      end

      # Check if registration is approved
      def approved?
        registration_status == 'approved'
      end

      # Check if registration is rejected
      def rejected?
        registration_status == 'rejected'
      end
    end

    # Collection wrapper for multiple responses (used in bulk operations with chunking)
    class BulkResponseCollection
      include Enumerable

      def initialize(responses)
        # Ensure responses is always an array
        @responses = responses.is_a?(Array) ? responses : [responses]
      end

      # Iterate over responses
      def each(&block)
        @responses.each(&block)
      end

      # Get total credits used across all responses
      def total_credits_used
        @responses.sum { |r| r.respond_to?(:credits_used) ? (r.credits_used || 0) : 0 }
      end

      # Get total numbers processed
      def total_numbers
        @responses.sum { |r| r.respond_to?(:total_numbers) ? (r.total_numbers || 0) : 0 }
      end

      # Get total successful sends
      def total_success_number
        @responses.sum { |r| r.respond_to?(:success_number) ? (r.success_number || 0) : 0 }
      end

      # Get total failed sends
      def total_failed_number
        total_numbers - total_success_number
      end

      # Check if all API calls were successful (not necessarily all messages)
      def all_api_calls_successful?
        @responses.all?(&:success?)
      end

      # Check if all individual messages were successfully sent
      def all_messages_successful?
        @responses.all? do |response|
          response.success? && 
          response.respond_to?(:all_successful?) && 
          response.all_successful?
        end
      end
      
      # Alias for the more useful all_messages_successful?
      alias_method :all_successful?, :all_messages_successful?
      
      # Alias for consistency with other response objects
      alias_method :success?, :all_api_calls_successful?

      # Check if any response had an error
      def error?
        !success?
      end

      # Get overall success rate
      def success_rate
        return 0 if total_numbers == 0
        (total_success_number.to_f / total_numbers * 100).round(2)
      end

      # Get all messages from all responses
      def all_messages
        @responses.flat_map { |r| r.respond_to?(:messages) ? r.messages : [] }
      end

      # Get response count
      def response_count
        @responses.length
      end

      # Chainable success handler (calls block if all responses successful)
      def on_success(&block)
        block.call(self) if all_successful? && block_given?
        self
      end

      # Chainable error handler (calls block if any response failed)
      def on_error(&block)
        block.call(self) if !all_successful? && block_given?
        self
      end

      # String representation
      def to_s
        "BulkResponseCollection(#{response_count} responses, #{total_numbers} total numbers, #{success_rate}% success rate)"
      end

      # Convert to hash representation (aggregated data)
      def to_h
        {
          responses: @responses.map { |r| r.respond_to?(:to_h) ? r.to_h : r },
          summary: {
            response_count: response_count,
            total_numbers: total_numbers,
            total_success_number: total_success_number,
            total_failed_number: total_failed_number,
            success_rate: success_rate,
            total_credits_used: total_credits_used
          }
        }
      end
      alias_method :to_hash, :to_h
    end
  end
end