# frozen_string_literal: true

require "test_helper"

class TestRetryHandler < Minitest::Test
  def setup
    @config = Cellcast::SMS::Configuration.new
    @config.max_retries = 2
    @config.base_delay = 0.1  # Short delay for tests
    @config.max_delay = 1.0
  end

  def test_successful_execution_no_retry
    call_count = 0
    
    result = Cellcast::SMS::RetryHandler.with_retries(config: @config) do
      call_count += 1
      "success"
    end

    assert_equal "success", result
    assert_equal 1, call_count
  end

  def test_retry_on_server_error
    call_count = 0
    
    result = Cellcast::SMS::RetryHandler.with_retries(config: @config) do
      call_count += 1
      if call_count < 3
        raise Cellcast::SMS::ServerError.new("Server error", status_code: 500)
      end
      "success"
    end

    assert_equal "success", result
    assert_equal 3, call_count
  end

  def test_retry_on_network_error
    call_count = 0
    
    result = Cellcast::SMS::RetryHandler.with_retries(config: @config) do
      call_count += 1
      if call_count < 2
        raise Cellcast::SMS::TimeoutError, "Request timeout"
      end
      "success"
    end

    assert_equal "success", result
    assert_equal 2, call_count
  end

  def test_retry_on_rate_limit_with_retry_after
    call_count = 0
    
    result = Cellcast::SMS::RetryHandler.with_retries(config: @config) do
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
      Cellcast::SMS::RetryHandler.with_retries(config: @config) do
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
      Cellcast::SMS::RetryHandler.with_retries(config: @config) do
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
      Cellcast::SMS::RetryHandler.with_retries(config: @config) do
        call_count += 1
        raise Cellcast::SMS::ServerError.new("Server error", status_code: 500)
      end
    end

    assert_equal "Server error", error.message
    assert_equal 3, call_count  # 1 initial + 2 retries
  end

  def test_exponential_backoff_calculation
    # Test delay calculation (without jitter for predictable testing)
    delay1 = Cellcast::SMS::RetryHandler.send(
      :calculate_delay, 
      1, 
      @config, 
      Cellcast::SMS::ServerError.new("test")
    )
    
    delay2 = Cellcast::SMS::RetryHandler.send(
      :calculate_delay, 
      2, 
      @config, 
      Cellcast::SMS::ServerError.new("test")
    )

    # Base delay should be around 0.1, second attempt around 0.2 (with jitter)
    assert_operator delay1, :>=, 0.05
    assert_operator delay1, :<=, 0.15
    assert_operator delay2, :>=, 0.15
    assert_operator delay2, :<=, 0.25
  end
end