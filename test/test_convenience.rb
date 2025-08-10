# frozen_string_literal: true

require "test_helper"

class TestConvenience < Minitest::Test
  def setup
    config = Cellcast::SMS::Configuration.new
    config.sandbox_mode = true
    @client = Cellcast.sms(api_key: "test_key", config: config)
  end

  def test_quick_send
    response = @client.quick_send(
      to: "+1234567890",
      message: "Hello world",
      from: "MyBrand"
    )

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
    assert response.dig("data", "messages", 0, "message_id"), "Should have message_id"
    assert_equal "Queued", response["msg"]
  end

  def test_quick_send_special_test_number_success
    response = @client.quick_send(
      to: "+15550000000",
      message: "Hello world",
      from: "MyBrand"
    )

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
    assert response.dig("data", "messages", 0, "message_id"), "Should have message_id"
    assert_equal "Queued", response["msg"]
  end

  def test_quick_send_special_test_number_failed
    response = @client.quick_send(
      to: "+15550000001",
      message: "Hello world",
      from: "MyBrand"
    )

    assert_instance_of Hash, response
    assert_equal "FAILED", response.dig("meta", "status")
    assert_equal "Message failed to send", response["msg"]
  end

  def test_broadcast
    response = @client.broadcast(
      to: ["+1234567890", "+1987654321"],
      message: "Broadcast message",
      from: "MyBrand"
    )

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
    assert_equal 2, response.dig("data", "total_numbers")
    assert_equal 2, response.dig("data", "success_number")
    assert_equal 2, response.dig("data", "messages").length
  end

  def test_broadcast_mixed_results
    response = @client.broadcast(
      to: ["+15550000000", "+15550000001"], # Success + failed
      message: "Broadcast message",
      from: "MyBrand"
    )

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
    data = response["data"]
    assert_equal 2, data["total_numbers"]
    assert_equal 1, data["success_number"]
    assert_equal 1, data["messages"].length
    # Note: Official API doesn't expose invalid contacts in successful responses
  end

  def test_get_message_status
    message_id = "test_message_123"
    response = @client.get_message_status(message_id: message_id)

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
  end

  def test_get_inbound_messages
    response = @client.get_inbound_messages(page: 1)

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
  end

  def test_send_to_nz
    response = @client.send_to_nz(
      to: "+64211234567",
      message: "Hello New Zealand!",
      from: "TEST"
    )

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
  end

  def test_mark_read
    response = @client.mark_read(message_id: "inbound_123")

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
  end

  def test_mark_all_read
    response = @client.mark_all_read

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
  end

  def test_balance
    response = @client.balance

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
    assert response.dig("data", "sms_balance"), "Should have SMS balance"
    assert response.dig("data", "mms_balance"), "Should have MMS balance"
  end

  def test_get_templates
    response = @client.get_templates

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
    assert response["data"].is_a?(Array), "Templates should be an array"
  end

  def test_get_optouts
    response = @client.get_optouts

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
  end

  def test_register_alpha_id
    response = @client.register_alpha_id(
      alpha_id: "TEST",
      purpose: "Marketing notifications"
    )

    assert_instance_of Hash, response
    assert_equal "SUCCESS", response.dig("meta", "status")
  end
end
