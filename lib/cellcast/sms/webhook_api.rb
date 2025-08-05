# frozen_string_literal: true

module Cellcast
  module SMS
    # Webhook API endpoints implementation
    # Following Sandi Metz rules: small focused class
    class WebhookApi
      def initialize(client)
        @client = client
      end

      # Create or update a webhook configuration
      # @param url [String] The webhook URL
      # @param events [Array<String>] Array of events to subscribe to
      # @param secret [String, nil] Optional webhook secret for verification
      # @return [Hash] API response
      def configure_webhook(url:, events:, secret: nil)
        validate_webhook_url(url)
        validate_events(events)

        body = {
          url: url,
          events: events
        }
        body[:secret] = secret if secret

        @client.request(method: :post, path: "webhooks/configure", body: body)
      end

      # Get current webhook configuration
      # @return [Hash] API response with webhook configuration
      def get_webhook_config
        @client.request(method: :get, path: "webhooks/config")
      end

      # Test webhook configuration by sending a test event
      # @param event_type [String] Type of test event to send
      # @return [Hash] API response
      def test_webhook(event_type: 'test')
        validate_event_type(event_type)
        
        body = { event_type: event_type }
        @client.request(method: :post, path: "webhooks/test", body: body)
      end

      # Delete webhook configuration
      # @return [Hash] API response
      def delete_webhook
        @client.request(method: :delete, path: "webhooks/config")
      end

      # Get webhook delivery logs
      # @param limit [Integer] Number of logs to retrieve
      # @param offset [Integer] Offset for pagination
      # @return [Hash] API response with delivery logs
      def get_delivery_logs(limit: 50, offset: 0)
        validate_pagination_params(limit, offset)
        
        params = "limit=#{limit}&offset=#{offset}"
        @client.request(method: :get, path: "webhooks/logs?#{params}")
      end

      # Retry failed webhook delivery
      # @param delivery_id [String] The delivery ID to retry
      # @return [Hash] API response
      def retry_delivery(delivery_id:)
        validate_delivery_id(delivery_id)
        
        body = { delivery_id: delivery_id }
        @client.request(method: :post, path: "webhooks/retry", body: body)
      end

      private

      def validate_webhook_url(url)
        raise ValidationError, "Webhook URL cannot be nil or empty" if url.nil? || url.strip.empty?
        raise ValidationError, "Webhook URL must be a string" unless url.is_a?(String)
        
        begin
          uri = URI.parse(url)
          raise ValidationError, "Webhook URL must be HTTP or HTTPS" unless %w[http https].include?(uri.scheme)
        rescue URI::InvalidURIError
          raise ValidationError, "Invalid webhook URL format"
        end
      end

      def validate_events(events)
        raise ValidationError, "Events must be an array" unless events.is_a?(Array)
        raise ValidationError, "Events array cannot be empty" if events.empty?
        
        valid_events = %w[
          sms.sent sms.delivered sms.failed
          sender_id.approved sender_id.rejected
          token.expired
        ]
        
        invalid_events = events - valid_events
        unless invalid_events.empty?
          raise ValidationError, "Invalid events: #{invalid_events.join(', ')}"
        end
      end

      def validate_event_type(event_type)
        valid_types = %w[test sms.sent sms.delivered sms.failed]
        unless valid_types.include?(event_type)
          raise ValidationError, "Invalid event type: #{event_type}"
        end
      end

      def validate_pagination_params(limit, offset)
        raise ValidationError, "Limit must be between 1 and 100" unless (1..100).cover?(limit)
        raise ValidationError, "Offset must be non-negative" unless offset >= 0
      end

      def validate_delivery_id(delivery_id)
        raise ValidationError, "Delivery ID cannot be nil or empty" if delivery_id.nil? || delivery_id.strip.empty?
      end
    end
  end
end