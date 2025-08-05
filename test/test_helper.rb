# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "cellcast"
require "minitest/autorun"
require "minitest/pride"

# Add mocha for mocking HTTP requests
require "mocha/minitest"

# Mock HTTP responses for testing
class MockHTTPResponse
  attr_reader :code, :body, :message

  def initialize(code:, body: nil, message: "OK", headers: {})
    @code = code.to_s
    @body = body
    @message = message
    @headers = headers
  end

  def [](header)
    @headers[header]
  end
end

# Test helper methods
module TestHelpers
  def mock_successful_response(body = {})
    MockHTTPResponse.new(
      code: 200,
      body: body.to_json
    )
  end

  def mock_error_response(code:, body: nil, message: "Error")
    MockHTTPResponse.new(
      code: code,
      body: body&.to_json,
      message: message
    )
  end

  def mock_rate_limit_response(retry_after: nil)
    headers = retry_after ? { "Retry-After" => retry_after.to_s } : {}
    MockHTTPResponse.new(
      code: 429,
      body: { error: "Rate limit exceeded" }.to_json,
      message: "Too Many Requests",
      headers: headers
    )
  end
end

class Minitest::Test
  include TestHelpers
end