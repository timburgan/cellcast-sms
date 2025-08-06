# frozen_string_literal: true

module Cellcast
  module SMS
    # Response wrapper objects for better data access and developer experience
    # Provides structured access to API responses instead of raw hashes
    
    # Base response class with common functionality
    class Response
      attr_reader :raw_response, :success, :status_code

      def initialize(raw_response, status_code: nil)
        @raw_response = raw_response
        @status_code = status_code
        @success = !raw_response.nil?
      end

      def success?
        @success
      end

      def [](key)
        raw_response[key.to_s]
      end

      def to_h
        raw_response
      end
    end

    # Response for SMS sending operations
    class SendMessageResponse < Response
      def initialize(raw_response, status_code: nil)
        super(raw_response, status_code: status_code)
        @data = raw_response.dig('data') || raw_response
      end

      def success?
        # Check both the top-level status and whether we have valid queue response
        api_success = raw_response['status'] == true
        has_valid_response = !@data.dig('queueResponse')&.empty?
        
        # For sandbox mode, also check if this specific number is in invalidContacts
        if to_number && @data.dig('invalidContacts')&.include?(to_number)
          return false
        end
        
        api_success && has_valid_response
      end
      
      def message_id
        # Try to get from queueResponse first (real API format), then fallback to direct fields
        queue_response = @data.dig('queueResponse')
        if queue_response&.any?
          queue_response.first['MessageId']
        else
          @data['message_id'] || @data['id'] || raw_response['message_id'] || raw_response['id']
        end
      end

      def status
        # Map the API response to expected status
        if @data.dig('queueResponse')&.any?
          'queued'
        elsif @data.dig('invalidContacts')&.any? || @data.dig('unsubscribeContacts')&.any?
          'failed'
        elsif raw_response['status'] == false
          'failed'
        else
          # Fallback to direct status field for backward compatibility
          @data['status'] || raw_response['status'] || 'unknown'
        end
      end

      def failed?
        status == 'failed' || !success?
      end

      def cost
        # Cost calculation could be based on parts or a fixed rate
        @data['cost'] || (success? ? 0.05 : 0.0)
      end

      def parts
        @data['parts'] || 1
      end

      def scheduled_at
        @data['scheduled_at']
      end

      def to_number
        queue_response = @data.dig('queueResponse')
        if queue_response&.any?
          queue_response.first['Number']
        else
          @data['to'] || raw_response['to']
        end
      end

      def failed_reason
        if @data.dig('error', 'errorMessage')
          @data.dig('error', 'errorMessage')
        elsif !success? && @data.dig('invalidContacts')&.any?
          'Invalid contact format'
        else
          @data['failed_reason'] || raw_response['failed_reason']
        end
      end
    end

    # Response for bulk SMS operations
    class BulkMessageResponse < Response
      def initialize(raw_response, status_code: nil)
        super(raw_response, status_code: status_code)
        @data = raw_response.dig('data') || raw_response
      end

      def messages
        @messages ||= build_message_responses
      end

      def total_count
        @data['totalValidContact'].to_i + @data['totalInvalidContact'].to_i + @data['totalUnsubscribeContact'].to_i
      end

      def successful_count
        @data['totalValidContact'].to_i
      end

      def failed_count
        @data['totalInvalidContact'].to_i + @data['totalUnsubscribeContact'].to_i
      end

      def total_cost
        # Estimate cost based on successful messages (0.05 per message)
        successful_count * 0.05
      end

      def invalid_contacts
        @data['invalidContacts'] || []
      end

      def unsubscribed_contacts
        @data['unsubscribeContacts'] || []
      end

      private

      def build_message_responses
        responses = []
        
        # Add successful messages
        queue_responses = @data['queueResponse'] || []
        queue_responses.each do |queue_item|
          response_data = {
            'data' => {
              'queueResponse' => [queue_item]
            },
            'status' => true
          }
          responses << SendMessageResponse.new(response_data)
        end

        # Add failed messages (invalid contacts)
        invalid_contacts.each do |contact|
          response_data = {
            'data' => {
              'queueResponse' => [],
              'invalidContacts' => [contact]
            },
            'status' => false
          }
          responses << SendMessageResponse.new(response_data)
        end

        # Add unsubscribed contacts
        unsubscribed_contacts.each do |contact|
          response_data = {
            'data' => {
              'queueResponse' => [],
              'unsubscribeContacts' => [contact]
            },
            'status' => false
          }
          responses << SendMessageResponse.new(response_data)
        end

        responses
      end
    end

    # Response for message status operations
    class MessageStatusResponse < Response
      def message_id
        self['message_id'] || self['id']
      end

      def status
        self['status']
      end

      def delivered?
        status == 'delivered'
      end

      def failed?
        status == 'failed'
      end

      def pending?
        %w[queued processing sent].include?(status)
      end

      def delivered_at
        self['delivered_at']
      end

      def failed_reason
        self['failed_reason']
      end
    end

    # Response for incoming message operations
    class IncomingMessageResponse < Response
      def message_id
        self['id']
      end

      def from
        self['from']
      end

      def to
        self['to']
      end

      def message
        self['message']
      end

      def received_at
        self['received_at']
      end

      def read?
        self['read'] == true
      end

      def original_message_id
        self['original_message_id']
      end

      def is_reply?
        !original_message_id.nil?
      end
    end

    # Response for list operations
    class ListResponse < Response
      def items
        @items ||= parse_items
      end

      def total
        self['total'] || items.length
      end

      def limit
        self['limit']
      end

      def offset
        self['offset']
      end

      def has_more?
        total > (offset || 0) + items.length
      end

      private

      def parse_items
        data = self['data'] || self['messages'] || self['items'] || []
        data.map { |item| item_class.new(item) }
      end

      def item_class
        Response
      end
    end

    # Response for message lists
    class MessageListResponse < ListResponse
      private

      def item_class
        MessageStatusResponse
      end
    end

    # Response for incoming message lists
    class IncomingListResponse < ListResponse
      def unread_count
        items.count { |msg| !msg.read? }
      end

      private

      def item_class
        IncomingMessageResponse
      end
    end
  end
end