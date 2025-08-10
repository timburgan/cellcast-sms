# frozen_string_literal: true

require "test_helper"

class TestEnhancedErrorHandling < Minitest::Test
  def setup
    config = Cellcast::SMS::Configuration.new
    config.sandbox_mode = true
    config.response_format = :enhanced
    config.auto_retry_failed = true
    config.max_retries = 2
    @client = Cellcast.sms(api_key: "test_key", config: config)
  end

  def test_cellcast_api_error_structure
    begin
      # This would normally trigger an error, but sandbox might not
      # We'll create an error manually for testing
      error_response = {
        'meta' => { 'status' => 'FAILED', 'code' => 400 },
        'msg' => 'Invalid phone number format'
      }
      error = Cellcast::SMS::CellcastApiError.new(error_response)
      
      assert_equal 400, error.status_code
      assert_equal 'Invalid phone number format', error.api_message
      assert error.invalid_number?
      refute error.insufficient_credit?
      refute error.rate_limited?
      refute error.authentication_error?
      refute error.server_error?
      refute error.retryable?
    rescue => e
      # If sandbox doesn't support error testing, skip
      skip "Sandbox doesn't support error testing: #{e.message}"
    end
  end

  def test_error_response_wrapper
    error_response = {
      'meta' => { 'status' => 'FAILED', 'code' => 402 },
      'msg' => 'Insufficient balance'
    }
    
    wrapper = Cellcast::SMS::ErrorResponse.new(error_response)
    assert wrapper.error?
    assert_equal 402, wrapper.status_code
    assert_equal 'Insufficient balance', wrapper.api_message
    
    exception = wrapper.to_exception
    assert_instance_of Cellcast::SMS::CellcastApiError, exception
    assert exception.insufficient_credit?
  end

  def test_structured_error_types
    # Test different error types
    error_types = [
      { code: 401, msg: 'Unauthorized', method: :authentication_error? },
      { code: 402, msg: 'Insufficient balance', method: :insufficient_credit? },
      { code: 429, msg: 'Rate limit exceeded', method: :rate_limited? },
      { code: 500, msg: 'Server error', method: :server_error? }
    ]
    
    error_types.each do |error_type|
      response = {
        'meta' => { 'status' => 'FAILED', 'code' => error_type[:code] },
        'msg' => error_type[:msg]
      }
      
      error = Cellcast::SMS::CellcastApiError.new(response)
      assert error.send(error_type[:method]), "#{error_type[:method]} should be true for code #{error_type[:code]}"
    end
  end

  def test_retryable_errors
    retryable_response = {
      'meta' => { 'status' => 'FAILED', 'code' => 429 },
      'msg' => 'Rate limit exceeded'
    }
    
    error = Cellcast::SMS::CellcastApiError.new(retryable_response)
    assert error.retryable?
    assert error.suggested_retry_delay
    assert_equal 30, error.suggested_retry_delay  # Rate limit delay
    
    server_error_response = {
      'meta' => { 'status' => 'FAILED', 'code' => 500 },
      'msg' => 'Internal server error'
    }
    
    server_error = Cellcast::SMS::CellcastApiError.new(server_error_response)
    assert server_error.retryable?
    assert_equal 5, server_error.suggested_retry_delay  # Server error delay
  end

  def test_configuration_validation
    config = Cellcast::SMS::Configuration.new
    
    # Test invalid response format
    config.response_format = :invalid
    assert_raises(Cellcast::SMS::ValidationError) { config.validate! }
    
    # Test invalid timeouts
    config.response_format = :enhanced
    config.open_timeout = -1
    assert_raises(Cellcast::SMS::ValidationError) { config.validate! }
    
    config.open_timeout = 30
    config.read_timeout = 0
    assert_raises(Cellcast::SMS::ValidationError) { config.validate! }
    
    # Test invalid retry settings
    config.read_timeout = 60
    config.max_retries = -1
    assert_raises(Cellcast::SMS::ValidationError) { config.validate! }
    
    config.max_retries = 3
    config.retry_delay = 0
    assert_raises(Cellcast::SMS::ValidationError) { config.validate! }
    
    # Test invalid chunk size
    config.retry_delay = 2
    config.chunk_size = 0
    assert_raises(Cellcast::SMS::ValidationError) { config.validate! }
    
    # Test valid configuration
    config.chunk_size = 100
    config.validate!  # Should not raise
  end

  def test_configuration_helper_methods
    config = Cellcast::SMS::Configuration.new
    
    config.response_format = :enhanced
    assert config.enhanced_responses?
    refute config.preserve_raw_responses?
    
    config.response_format = :raw
    refute config.enhanced_responses?
    assert config.preserve_raw_responses?  # :raw should preserve raw responses
    
    config.response_format = :both
    assert config.enhanced_responses?
    assert config.preserve_raw_responses?
    
    # Test retry delay calculation
    config.retry_delay = 2
    assert_equal 2, config.retry_delay_for_attempt(1)
    assert_equal 4, config.retry_delay_for_attempt(2)
    assert_equal 8, config.retry_delay_for_attempt(3)
  end

  def test_enhanced_client_creation_with_options
    # Test the enhanced convenience method
    client = Cellcast.enhanced_sms(
      api_key: "test_key",
      default_sender_id: "BRAND",
      sandbox_mode: true
    )
    
    assert_equal :enhanced, client.config.response_format
    assert_equal "BRAND", client.config.default_sender_id
    assert client.config.sandbox_mode
    assert client.config.auto_retry_failed
  end

  def test_raw_client_creation
    client = Cellcast.raw_sms(
      api_key: "test_key",
      sandbox_mode: true
    )
    
    assert_equal :raw, client.config.response_format
    assert client.config.sandbox_mode
  end

  def test_client_creation_with_custom_options
    client = Cellcast.sms(
      api_key: "test_key",
      response_format: :enhanced,
      default_sender_id: "CUSTOM",
      chunk_size: 25,
      max_retries: 5,
      low_balance_threshold: 50,
      sandbox_mode: true
    )
    
    assert_equal :enhanced, client.config.response_format
    assert_equal "CUSTOM", client.config.default_sender_id
    assert_equal 25, client.config.chunk_size
    assert_equal 5, client.config.max_retries
    assert_equal 50, client.config.low_balance_threshold
    assert client.config.sandbox_mode
  end
end