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
      def success?
        super && !failed?
      end
      
      def message_id
        self['message_id'] || self['id']
      end

      def status
        self['status']
      end

      def failed?
        status == 'failed'
      end

      def cost
        self['cost']
      end

      def parts
        self['parts'] || 1
      end

      def scheduled_at
        self['scheduled_at']
      end
    end

    # Response for bulk SMS operations
    class BulkMessageResponse < Response
      def messages
        @messages ||= (self['messages'] || []).map do |msg|
          SendMessageResponse.new(msg)
        end
      end

      def total_count
        messages.length
      end

      def successful_count
        messages.count(&:success?)
      end

      def failed_count
        total_count - successful_count
      end

      def total_cost
        messages.sum { |msg| msg.cost.to_f }
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