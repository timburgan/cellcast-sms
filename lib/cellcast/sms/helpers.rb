# frozen_string_literal: true

module Cellcast
  module SMS
    # Helper class for tracking message delivery status
    class MessageTracker
      def initialize(client)
        @client = client
      end

      # Track a message until it's delivered or failed
      # @param message_id [String] The message ID to track
      # @param timeout [Integer] Maximum time to wait in seconds (default: 300)
      # @param check_interval [Integer] How often to check status in seconds (default: 30)
      # @return [MessageDetailsResponse] Final message status
      def track_until_delivered(message_id, timeout: 300, check_interval: 30)
        start_time = Time.now
        
        loop do
          response = @client.get_message_status(message_id: message_id)
          
          # Return if message is in a final state
          return response if response.delivered? || response.failed?
          
          # Check timeout
          if Time.now - start_time > timeout
            raise TimeoutError, "Message tracking timed out after #{timeout} seconds"
          end
          
          sleep(check_interval)
        end
      end

      # Track multiple messages
      # @param message_ids [Array<String>] Array of message IDs to track
      # @param timeout [Integer] Maximum time to wait for all messages
      # @param check_interval [Integer] How often to check status
      # @return [Hash] Hash of message_id => final_response
      def track_multiple(message_ids, timeout: 300, check_interval: 30)
        start_time = Time.now
        results = {}
        remaining_ids = message_ids.dup
        
        while remaining_ids.any?
          remaining_ids.each do |message_id|
            response = @client.get_message_status(message_id: message_id)
            
            if response.delivered? || response.failed?
              results[message_id] = response
              remaining_ids.delete(message_id)
            end
          end
          
          break if remaining_ids.empty?
          
          if Time.now - start_time > timeout
            # Return partial results and mark remaining as timed out
            remaining_ids.each do |message_id|
              results[message_id] = :timeout
            end
            break
          end
          
          sleep(check_interval) if remaining_ids.any?
        end
        
        results
      end

      # Get delivery rate for a set of messages
      # @param message_ids [Array<String>] Message IDs to check
      # @return [Hash] Statistics about delivery success
      def delivery_stats(message_ids)
        responses = message_ids.map do |message_id|
          @client.get_message_status(message_id: message_id)
        end
        
        delivered = responses.count(&:delivered?)
        failed = responses.count(&:failed?)
        pending = responses.count(&:pending?)
        
        {
          total: message_ids.length,
          delivered: delivered,
          failed: failed,
          pending: pending,
          delivery_rate: message_ids.empty? ? 0 : (delivered.to_f / message_ids.length * 100).round(2)
        }
      end
    end

    # Helper class for handling paginated inbound messages
    class PaginatedInboundMessages
      def initialize(client)
        @client = client
      end

      # Get all messages across all pages (use with caution for large datasets)
      # @param limit [Integer, nil] Maximum number of messages to retrieve
      # @yield [InboundMessage] Each message if block given
      # @return [Enumerator] If no block given
      def all_messages(limit: nil)
        return enum_for(:all_messages, limit: limit) unless block_given?
        
        page = 1
        count = 0
        
        loop do
          response = @client.get_inbound_messages(page: page)
          
          break unless response.success?
          
          response.each_message do |message|
            yield message
            count += 1
            return if limit && count >= limit
          end
          
          break unless response.has_more_pages?
          page += 1
        end
      end

      # Get only unread messages across all pages
      # @param limit [Integer, nil] Maximum number of messages to retrieve
      # @return [Array<InboundMessage>] Array of unread messages
      def all_unread_messages(limit: nil)
        messages = []
        
        all_messages(limit: limit) do |message|
          messages << message if message.unread?
        end
        
        messages
      end

      # Get messages from a specific date range
      # @param start_date [Time, Date] Start of date range
      # @param end_date [Time, Date] End of date range
      # @param limit [Integer, nil] Maximum number of messages
      # @return [Array<InboundMessage>] Filtered messages
      def messages_in_date_range(start_date, end_date, limit: nil)
        messages = []
        
        all_messages(limit: limit) do |message|
          received_at = message.received_at
          next unless received_at
          
          if received_at >= start_date && received_at <= end_date
            messages << message
          end
        end
        
        messages
      end

      # Mark all unread messages as read
      # @param before [Time, nil] Only mark messages received before this time
      # @return [Integer] Number of messages marked as read
      def mark_all_unread_as_read(before: nil)
        marked_count = 0
        
        all_unread_messages.each do |message|
          # Skip if before filter is set and message is after the time
          if before && message.received_at && message.received_at > before
            next
          end
          
          begin
            @client.mark_read(message_id: message.message_id)
            marked_count += 1
          rescue CellcastApiError => e
            # Log error but continue with other messages
            puts "Failed to mark message #{message.message_id} as read: #{e.message}" if @client.config.logger
          end
        end
        
        marked_count
      end

      # Get message statistics
      # @param pages [Integer] Number of pages to analyze (default: 1)
      # @return [Hash] Statistics about messages
      def message_stats(pages: 1)
        total_messages = 0
        unread_count = 0
        read_count = 0
        
        (1..pages).each do |page|
          response = @client.get_inbound_messages(page: page)
          break unless response.success?
          
          response.each_message do |message|
            total_messages += 1
            if message.read?
              read_count += 1
            else
              unread_count += 1
            end
          end
          
          break unless response.has_more_pages?
        end
        
        {
          total: total_messages,
          read: read_count,
          unread: unread_count,
          read_rate: total_messages == 0 ? 0 : (read_count.to_f / total_messages * 100).round(2)
        }
      end
    end

    # Helper class for smart bulk operations with automatic chunking and retry
    class BulkOperationManager
      def initialize(client)
        @client = client
        @config = client.config
      end

      # Send messages with automatic chunking
      # @param recipients [Array<String>] Array of phone numbers
      # @param message [String] Message text
      # @param from [String, nil] Sender ID
      # @param chunk_size [Integer] Messages per chunk
      # @return [BulkResponseCollection] Collection of responses
      def smart_broadcast(recipients, message, from: nil, chunk_size: nil)
        chunk_size ||= @config.chunk_size
        
        # Single recipient - use quick_send
        if recipients.length == 1
          response = @client.quick_send(to: recipients.first, message: message, from: from)
          return BulkResponseCollection.new([response])
        end
        
        responses = []
        
        recipients.each_slice(chunk_size) do |chunk|
          messages = chunk.map do |phone|
            { to: phone, message: message, sender_id: from }.compact
          end
          
          begin
            response = @client.sms.send_bulk(messages: messages)
            wrapped_response = wrap_response(response, BulkSmsResponse)
            responses << wrapped_response
          rescue CellcastApiError => e
            # Create error response for failed chunk
            error_response = create_error_response(e, chunk.length)
            responses << error_response
          end
        end
        
        BulkResponseCollection.new(responses)
      end

      # Send messages with retry on failure
      # @param recipients [Array<String>] Array of phone numbers  
      # @param message [String] Message text
      # @param from [String, nil] Sender ID
      # @param max_retries [Integer] Maximum retry attempts
      # @return [BulkResponseCollection] Collection of responses
      def broadcast_with_retry(recipients, message, from: nil, max_retries: nil)
        max_retries ||= @config.max_retries
        
        attempt = 0
        
        begin
          smart_broadcast(recipients, message, from: from)
        rescue CellcastApiError => e
          attempt += 1
          
          if e.retryable? && attempt <= max_retries
            delay = @config.retry_delay_for_attempt(attempt)
            sleep(delay)
            retry
          else
            raise
          end
        end
      end

      # Send personalized messages (different message per recipient)
      # @param personalized_messages [Array<Hash>] Array of {to:, message:, from:} hashes
      # @param chunk_size [Integer] Messages per chunk
      # @return [BulkResponseCollection] Collection of responses
      def send_personalized(personalized_messages, chunk_size: nil)
        chunk_size ||= @config.chunk_size
        responses = []
        
        personalized_messages.each_slice(chunk_size) do |chunk|
          begin
            response = @client.sms.send_bulk(messages: chunk)
            wrapped_response = wrap_response(response, BulkSmsResponse)
            responses << wrapped_response
          rescue CellcastApiError => e
            error_response = create_error_response(e, chunk.length)
            responses << error_response
          end
        end
        
        BulkResponseCollection.new(responses)
      end

      private

      def wrap_response(raw_response, wrapper_class)
        if @config.enhanced_responses?
          wrapper_class.new(raw_response)
        else
          raw_response
        end
      end

      def create_error_response(error, recipient_count)
        error_data = {
          'meta' => { 'status' => 'FAILED', 'code' => error.status_code },
          'msg' => error.api_message,
          'data' => {
            'total_numbers' => recipient_count,
            'success_number' => 0,
            'credits_used' => 0,
            'messages' => []
          }
        }
        
        wrap_response(error_data, BulkSmsResponse)
      end
    end
  end
end