# frozen_string_literal: true

# Enhanced Cellcast v3 API diagnostics with message lifecycle testing
# Tests actual inbound message retrieval and marking behavior
# Usage:
#   CELLCASTKEY=your_key ruby examples/enhanced_diagnostics.rb

require 'json'
require 'net/http'
require 'uri'
require 'time'

# Load gem from local lib without installing
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'cellcast'

BASE_URL = 'https://cellcast.com.au/api/v3'

def env_key
  ENV['CELLCASTKEY']
end

def abort_unless_key!
  if env_key.nil? || env_key.strip.empty?
    abort "CELLCASTKEY environment variable is not set. Export it and retry."
  end
end

def make_request(method, path, body = nil)
  uri = URI("#{BASE_URL}/#{path}")
  
  case method.to_s.upcase
  when 'GET'
    req = Net::HTTP::Get.new(uri)
  when 'POST'
    req = Net::HTTP::Post.new(uri)
    req.body = body.to_json if body
    req['Content-Type'] = 'application/json'
  else
    raise "Unsupported method: #{method}"
  end
  
  req['APPKEY'] = env_key
  req['Accept'] = 'application/json'
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  res = http.request(req)
  
  [res.code.to_i, res.body]
rescue StandardError => e
  warn "[#{method}] #{path} error: #{e.class}: #{e.message}"
  [0, nil]
end

def parse_json(body)
  JSON.parse(body)
rescue JSON::ParserError
  { 'raw_response' => body }
end

def get_messages_summary(payload)
  data = payload['data'] || {}
  responses = data['responses'] || data['data'] || data['messages'] || []
  
  {
    status: payload.dig('meta', 'status'),
    message: payload['msg'],
    total: data['total'],
    count: responses.length,
    message_ids: responses.map { |r| r['message_id'] }.compact
  }
end

def test_lifecycle_behavior
  abort_unless_key!
  
  puts "=== Enhanced Cellcast API Lifecycle Test ==="
  puts "Testing whether get-responses actually marks messages as read"
  puts
  
  # Initial state
  puts "1. Getting initial message state..."
  code, body = make_request(:get, 'get-responses?page=1&type=sms')
  
  if code != 200
    puts "   ❌ Failed to get initial state: HTTP #{code}"
    return
  end
  
  initial = parse_json(body)
  initial_summary = get_messages_summary(initial)
  
  puts "   📊 Initial state:"
  puts "      Status: #{initial_summary[:status]}"
  puts "      Message: #{initial_summary[:message]}"
  puts "      Total: #{initial_summary[:total]}"
  puts "      Count: #{initial_summary[:count]}"
  puts "      Message IDs: #{initial_summary[:message_ids]}"
  
  if initial_summary[:count] == 0
    puts "\n   ⚠️  No messages available for lifecycle testing"
    puts "   💡 To test properly, send an SMS to your shared number first"
    return
  end
  
  # Wait a moment then re-read
  puts "\n2. Re-reading after 2 seconds..."
  sleep(2)
  
  code, body = make_request(:get, 'get-responses?page=1&type=sms')
  reread = parse_json(body)
  reread_summary = get_messages_summary(reread)
  
  puts "   📊 After re-read:"
  puts "      Status: #{reread_summary[:status]}"
  puts "      Message: #{reread_summary[:message]}"
  puts "      Total: #{reread_summary[:total]}"
  puts "      Count: #{reread_summary[:count]}"
  puts "      Message IDs: #{reread_summary[:message_ids]}"
  
  # Compare
  puts "\n3. Comparison:"
  if initial_summary[:count] == reread_summary[:count]
    puts "   ✅ Message count unchanged: #{initial_summary[:count]} -> #{reread_summary[:count]}"
    puts "   ✅ Messages NOT automatically marked as read by GET"
  else
    puts "   ❌ Message count changed: #{initial_summary[:count]} -> #{reread_summary[:count]}"
    puts "   ❌ Messages may be auto-marked as read by GET"
  end
  
  if initial_summary[:message_ids] == reread_summary[:message_ids]
    puts "   ✅ Same message IDs returned"
  else
    puts "   ❌ Different message IDs returned"
    puts "      Before: #{initial_summary[:message_ids]}"
    puts "      After:  #{reread_summary[:message_ids]}"
  end
  
  # Test explicit marking if we have messages
  if reread_summary[:count] > 0 && reread_summary[:message_ids].any?
    puts "\n4. Testing explicit mark-as-read..."
    
    first_message_id = reread_summary[:message_ids].first
    puts "   Marking message #{first_message_id} as read..."
    
    code, body = make_request(:post, 'inbound-read', { message_id: first_message_id })
    
    if code == 200
      mark_response = parse_json(body)
      puts "   ✅ Mark-as-read successful: #{mark_response['msg']}"
      
      # Check if message disappears
      sleep(1)
      code, body = make_request(:get, 'get-responses?page=1&type=sms')
      after_mark = parse_json(body)
      after_mark_summary = get_messages_summary(after_mark)
      
      puts "   📊 After explicit marking:"
      puts "      Count: #{after_mark_summary[:count]}"
      puts "      Message IDs: #{after_mark_summary[:message_ids]}"
      
      if after_mark_summary[:count] < reread_summary[:count]
        puts "   ✅ Message count decreased - explicit marking works"
      else
        puts "   ❌ Message count unchanged - explicit marking may not work"
      end
      
    else
      puts "   ❌ Mark-as-read failed: HTTP #{code}"
      puts "   Response: #{body}"
    end
  end
  
  puts "\n=== Test Complete ==="
end

def test_gem_vs_raw_detailed
  puts "\n=== Detailed Gem vs Raw Comparison ==="
  
  # Raw API
  code, raw_body = make_request(:get, 'get-responses?page=1&type=sms')
  raw_data = parse_json(raw_body)
  
  # Gem API
  client = Cellcast.sms(api_key: env_key)
  gem_response = client.get_inbound_messages(page: 1)
  gem_data = gem_response.respond_to?(:to_h) ? gem_response.to_h : gem_response
  
  puts "Raw API response keys: #{raw_data.keys}"
  puts "Gem response keys: #{gem_data.keys}"
  
  if raw_data.keys == gem_data.keys
    puts "✅ Root keys match"
  else
    puts "❌ Root keys differ"
  end
  
  # Check if gem wrapper works
  if gem_response.respond_to?(:messages)
    puts "Gem messages count: #{gem_response.messages.length}"
    if gem_response.messages.any?
      msg = gem_response.messages.first
      puts "First message structure:"
      puts "  from: #{msg.from.inspect}"
      puts "  body: #{msg.body.inspect}"
      puts "  message_id: #{msg.message_id.inspect}"
      puts "  received_at: #{msg.received_at.inspect}"
      puts "  read?: #{msg.read?}"
    end
  else
    puts "❌ Gem response doesn't have messages method"
  end
end

if __FILE__ == $0
  test_lifecycle_behavior
  test_gem_vs_raw_detailed
end
