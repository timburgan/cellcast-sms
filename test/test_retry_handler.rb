# frozen_string_literal: true

require "test_helper"

class TestRetryHandler < Minitest::Test
  def test_successful_execution_no_retry
    call_count = 0

    result = Cellcast::SMS::RetryHandler.with_retries do
      call_count += 1
      "success"
    end

    assert_equal "success", result
    assert_equal 1, call_count
  end

  def test_retry_on_server_error
    call_count = 0

    result = Cellcast::SMS::RetryHandler.with_retries do
      call_count += 1
      raise Cellcast::SMS::ServerError.new("Server error", status_code: 500) if call_count < 3

      "success"
    end

    assert_equal "success", result
    assert_equal 3, call_count
  end

  def test_retry_on_network_error
    call_count = 0

    result = Cellcast::SMS::RetryHandler.with_retries do
      call_count += 1
      raise Cellcast::SMS::TimeoutError, "Request timeout" if call_count < 2

      "success"
    end

    assert_equal "success", result
    assert_equal 2, call_count
  end

  def test_retry_on_rate_limit_with_retry_after
    call_count = 0

    result = Cellcast::SMS::RetryHandler.with_retries do
      call_count += 1
      if call_count < 2
        raise Cellcast::SMS::RateLimitError.new(
          "Rate limited",
          status_code: 429,
          retry_after: 0.1
        )
      end
      "success"
    end

    assert_equal "success", result
    assert_equal 2, call_count
  end

  def test_no_retry_on_authentication_error
    call_count = 0

    error = assert_raises(Cellcast::SMS::AuthenticationError) do
      Cellcast::SMS::RetryHandler.with_retries do
        call_count += 1
        raise Cellcast::SMS::AuthenticationError, "Invalid API key"
      end
    end

    assert_equal "Invalid API key", error.message
    assert_equal 1, call_count
  end

  def test_no_retry_on_validation_error
    call_count = 0

    error = assert_raises(Cellcast::SMS::ValidationError) do
      Cellcast::SMS::RetryHandler.with_retries do
        call_count += 1
        raise Cellcast::SMS::ValidationError, "Invalid input"
      end
    end

    assert_equal "Invalid input", error.message
    assert_equal 1, call_count
  end

  def test_max_retries_exceeded
    call_count = 0

    error = assert_raises(Cellcast::SMS::ServerError) do
      Cellcast::SMS::RetryHandler.with_retries do
        call_count += 1
        raise Cellcast::SMS::ServerError.new("Server error", status_code: 500)
      end
    end

    assert_equal "Server error", error.message
    assert_equal 4, call_count # 1 initial + 3 retries (MAX_RETRIES = 3)
  end

  def test_exponential_backoff_calculation
    # Test delay calculation (without jitter for predictable testing)
    delay1 = Cellcast::SMS::RetryHandler.send(
      :calculate_delay,
      1,
      Cellcast::SMS::ServerError.new("test")
    )

    delay2 = Cellcast::SMS::RetryHandler.send(
      :calculate_delay,
      2,
      Cellcast::SMS::ServerError.new("test")
    )

    # Base delay should be around 1.0, second attempt around 2.0 (with jitter)
    assert_operator delay1, :>=, 0.75
    assert_operator delay1, :<=, 1.25
    assert_operator delay2, :>=, 1.5
    assert_operator delay2, :<=, 2.5
  end

  def test_hardcoded_retry_constants
    assert_equal 3, Cellcast::SMS::RetryHandler::MAX_RETRIES
    assert_equal 1.0, Cellcast::SMS::RetryHandler::BASE_DELAY
    assert_equal 32.0, Cellcast::SMS::RetryHandler::MAX_DELAY
    assert_equal 2.0, Cellcast::SMS::RetryHandler::BACKOFF_MULTIPLIER
  end
end
