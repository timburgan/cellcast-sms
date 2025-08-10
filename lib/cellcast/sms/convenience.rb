# frozen_string_literal: true

module Cellcast
  module SMS
    # Enhanced convenience methods with smart response handling and chainable operations
    # Provides developer-friendly API with automatic response wrapping based on configuration
    module ConvenienceMethods
      # Send a quick SMS with enhanced response handling
      # @param to [String] Phone number to send to
      # @param message [String] Message content
      # @param from [String, nil] Optional sender ID (uses default if not provided)
      # @return [SendSmsResponse, Hash] Enhanced response object or raw hash based on config
      def quick_send(to:, message:, from: nil)
        from ||= config.default_sender_id if config.default_sender_id
        
        raw_response = sms.send_message(to: to, message: message, sender_id: from)
        wrap_response(raw_response, SendSmsResponse)
      end

      # Send SMS with automatic retry on failure
      # @param to [String] Phone number to send to
      # @param message [String] Message content  
      # @param from [String, nil] Optional sender ID
      # @param max_retries [Integer] Maximum retry attempts (uses config default if not provided)
      # @return [SendSmsResponse, Hash] Enhanced response object or raw hash
      def quick_send_with_retry(to:, message:, from: nil, max_retries: nil)
        max_retries ||= config.max_retries
        attempt = 0
        
        begin
          quick_send(to: to, message: message, from: from)
        rescue CellcastApiError => e
          attempt += 1
          
          if e.retryable? && attempt <= max_retries
            delay = config.retry_delay_for_attempt(attempt)
            sleep(delay)
            retry
          else
            raise
          end
        end
      end

      # Quick send SMS to multiple recipients (simple bulk operation)
      # @param to [Array<String>] Array of phone numbers
      # @param message [String] Message content
      # @param from [String, nil] Optional sender ID
      # @return [BulkSmsResponse, BulkResponseCollection] Enhanced response object
      def quick_send_bulk(to:, message:, from: nil)
        from ||= config.default_sender_id if config.default_sender_id
        broadcast(to: to, message: message, from: from)
      end

      # Send SMS to multiple recipients with smart chunking
      # @param to [Array<String>] Array of phone numbers
      # @param message [String] Message content
      # @param from [String, nil] Optional sender ID
      # @param chunk_size [Integer, nil] Custom chunk size (uses config default if not provided)
      # @return [BulkSmsResponse, BulkResponseCollection, Hash] Response based on number of recipients and config
      def broadcast(to:, message:, from: nil, chunk_size: nil)
        from ||= config.default_sender_id if config.default_sender_id
        chunk_size ||= config.chunk_size
        
        # Single recipient optimization
        return quick_send(to: to.first, message: message, from: from) if to.length == 1
        
        # Multiple recipients with chunking
        if to.length <= chunk_size
          # Single chunk - use bulk API directly
          messages = to.map { |phone| { to: phone, message: message, sender_id: from }.compact }
          raw_response = sms.send_bulk(messages: messages)
          wrap_response(raw_response, BulkSmsResponse)
        else
          # Multiple chunks - use bulk operation manager
          bulk_manager.smart_broadcast(to, message, from: from, chunk_size: chunk_size)
        end
      end

      # Send SMS with automatic retry and chunking
      # @param to [Array<String>] Array of phone numbers
      # @param message [String] Message content
      # @param from [String, nil] Optional sender ID
      # @param max_retries [Integer, nil] Maximum retry attempts
      # @return [BulkSmsResponse, BulkResponseCollection] Enhanced response
      def broadcast_with_retry(to:, message:, from: nil, max_retries: nil)
        bulk_manager.broadcast_with_retry(to, message, from: from, max_retries: max_retries)
      end

      # Send personalized messages (different message per recipient)
      # @param messages [Array<Hash>] Array of {to:, message:, from:} hashes
      # @param chunk_size [Integer, nil] Custom chunk size
      # @return [BulkSmsResponse, BulkResponseCollection] Enhanced response
      def send_personalized(messages:, chunk_size: nil)
        # Apply default sender ID to messages that don't have one
        if config.default_sender_id
          messages = messages.map do |msg|
            msg[:sender_id] ||= config.default_sender_id
            msg
          end
        end
        
        bulk_manager.send_personalized(messages, chunk_size: chunk_size)
      end

      # Get SMS message status and details with enhanced response
      # @param message_id [String] The message ID to look up
      # @return [MessageDetailsResponse, Hash] Enhanced message details or raw hash
      def get_message_status(message_id:)
        raw_response = sms.get_message(message_id: message_id)
        wrap_response(raw_response, MessageDetailsResponse)
      end

      # Track message until delivered or failed
      # @param message_id [String] Message ID to track
      # @param timeout [Integer] Maximum time to wait (default: 300 seconds)
      # @param check_interval [Integer] Check interval (default: 30 seconds)
      # @return [MessageDetailsResponse] Final message status
      def track_message_delivery(message_id:, timeout: 300, check_interval: 30)
        message_tracker.track_until_delivered(message_id, timeout: timeout, check_interval: check_interval)
      end

      # Get inbound messages/responses with enhanced pagination
      # @param page [Integer] Page number for pagination (default: 1)
      # @return [InboundMessagesResponse, Hash] Enhanced inbound messages or raw hash
      def get_inbound_messages(page: 1)
        raw_response = sms.get_responses(page: page)
        wrap_response(raw_response, InboundMessagesResponse)
      end

      # Get all inbound messages across all pages (use with caution for large datasets)
      # @param limit [Integer, nil] Maximum number of messages to retrieve
      # @param unread_only [Boolean] Only return unread messages
      # @return [Array<InboundMessage>] Array of message objects
      def get_all_inbound_messages(limit: nil, unread_only: false)
        if unread_only
          paginated_inbound.all_unread_messages(limit: limit)
        else
          paginated_inbound.all_messages(limit: limit).to_a
        end
      end

      # Get inbound message statistics
      # @param pages [Integer] Number of pages to analyze (default: 1)
      # @return [Hash] Statistics about read/unread messages
      def inbound_message_stats(pages: 1)
        paginated_inbound.message_stats(pages: pages)
      end

      # Send SMS to New Zealand numbers
      # @param to [String] NZ phone number to send to
      # @param message [String] Message content
      # @param from [String, nil] Optional sender ID
      # @return [SendSmsResponse, Hash] Enhanced response or raw hash
      def send_to_nz(to:, message:, from: nil)
        from ||= config.default_sender_id if config.default_sender_id
        
        raw_response = sms.send_message_nz(to: to, message: message, sender_id: from)
        wrap_response(raw_response, SendSmsResponse)
      end

      # Get account balance with enhanced response
      # @return [AccountBalanceResponse, Hash] Enhanced account balance or raw hash
      def balance
        raw_response = account.get_account_balance
        wrap_response(raw_response, AccountBalanceResponse)
      end

      # Check if account has low balance
      # @param sms_threshold [Integer] SMS balance threshold (default: uses config)
      # @param mms_threshold [Integer] MMS balance threshold (default: 5)
      # @return [Boolean] True if balance is low
      def low_balance?(sms_threshold: nil, mms_threshold: 5)
        sms_threshold ||= config.low_balance_threshold
        balance_response = balance
        
        if config.enhanced_responses?
          balance_response.low_balance?(sms_threshold, mms_threshold)
        else
          sms_bal = balance_response.dig('data', 'sms_balance')
          mms_bal = balance_response.dig('data', 'mms_balance')
          
          # Convert string values to float for comparison
          sms_val = sms_bal.is_a?(String) ? sms_bal.to_f : (sms_bal || 0)
          mms_val = mms_bal.is_a?(String) ? mms_bal.to_f : (mms_bal || 0)
          
          (sms_val < sms_threshold) || (mms_val < mms_threshold)
        end
      end

      # Get SMS templates with enhanced response
      # @return [TemplatesResponse, Hash] Enhanced templates response or raw hash
      def get_templates
        raw_response = account.get_templates
        wrap_response(raw_response, TemplatesResponse)
      end

      # Find template by ID or name
      # @param identifier [String] Template ID or name to search for
      # @return [Hash, nil] Template data if found
      def find_template(identifier)
        templates_response = get_templates
        
        if config.enhanced_responses?
          templates_response.find_template(identifier)
        else
          templates = templates_response['data'] || []
          templates.find { |t| t['id'] == identifier || t['name'] == identifier }
        end
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
      # @return [RegistrationResponse, Hash] Enhanced registration response or raw hash
      def register_alpha_id(alpha_id:, purpose:, business_registration: nil, contact_info: nil)
        raw_response = sender_id.register_alpha_id(
          alpha_id: alpha_id,
          purpose: purpose,
          business_registration: business_registration,
          contact_info: contact_info
        )
        wrap_response(raw_response, RegistrationResponse)
      end

      # Send SMS using a template with enhanced response
      # @param template_id [String] The template ID to use
      # @param numbers [Array] Array of recipient objects with number and personalization data
      # @param from [String, nil] Optional sender ID
      # @return [BulkSmsResponse, Hash] Enhanced response or raw hash
      def send_template(template_id:, numbers:, from: nil)
        from ||= config.default_sender_id if config.default_sender_id
        
        raw_response = sms.send_message_template(template_id: template_id, numbers: numbers, sender_id: from)
        wrap_response(raw_response, BulkSmsResponse)
      end

      # Mark inbound message as read
      # @param message_id [String] The inbound message ID to mark as read
      # @return [Hash] Raw API response
      def mark_read(message_id:)
        sms.mark_inbound_read(message_id: message_id)
      end

      # Mark all inbound messages as read
      # @param before [String, Time, nil] Optional timestamp to mark messages before this time as read
      # @return [Hash] Raw API response
      def mark_all_read(before: nil)
        timestamp = before.is_a?(Time) ? before.iso8601 : before
        sms.mark_inbound_read_bulk(timestamp: timestamp)
      end

      # Mark all unread messages as read with enhanced functionality
      # @param before [Time, nil] Only mark messages received before this time
      # @return [Integer] Number of messages marked as read
      def mark_all_unread_as_read(before: nil)
        paginated_inbound.mark_all_unread_as_read(before: before)
      end

      # Get delivery statistics for multiple messages
      # @param message_ids [Array<String>] Array of message IDs to check
      # @return [Hash] Delivery statistics
      def delivery_stats(message_ids)
        message_tracker.delivery_stats(message_ids)
      end

      private

      # Wrap raw API response based on configuration
      def wrap_response(raw_response, wrapper_class)
        if config.enhanced_responses?
          wrapper_class.new(raw_response)
        else
          raw_response
        end
      end

      # Get message tracker instance
      def message_tracker
        @message_tracker ||= MessageTracker.new(self)
      end

      # Get paginated inbound messages helper
      def paginated_inbound
        @paginated_inbound ||= PaginatedInboundMessages.new(self)
      end

      # Get bulk operation manager
      def bulk_manager
        @bulk_manager ||= BulkOperationManager.new(self)
      end
    end
  end
end
