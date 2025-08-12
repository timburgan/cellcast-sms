# frozen_string_literal: true

# Cellcast v3 API diagnostics: compares raw API vs gem behavior for inbound messages.
# Safe: uses only GET endpoints; does not mark messages as read or send SMS.
# Usage:
#   CELLCASTKEY=your_key ruby examples/diagnose_cellcast.rb

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

def get_raw_inbound(page: 1, type: 'sms')
  uri = URI("#{BASE_URL}/get-responses?page=#{page}&type=#{type}")
  req = Net::HTTP::Get.new(uri)
  req['APPKEY'] = env_key
  req['Accept'] = 'application/json'
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  res = http.request(req)
  [res.code.to_i, res.body]
rescue StandardError => e
  warn "[raw] request error: #{e.class}: #{e.message}"
  [0, nil]
end

def parse_json(body)
  JSON.parse(body)
rescue JSON::ParserError
  { 'raw_response' => body }
end

def print_header(title)
  puts "\n=== #{title} ==="
end

def summarize_inbound_payload(payload)
  data = payload['data']
  responses = if data.is_a?(Hash)
                data['responses'] || data['data'] || data['messages']
              else
                nil
              end
  {
    meta_status: payload.dig('meta', 'status'),
    msg: payload['msg'],
    keys_at_root: payload.keys,
    data_keys: (data.is_a?(Hash) ? data.keys : []),
    total: data.is_a?(Hash) ? (data['total'] || data['count'] || data['total_messages']) : nil,
    current_page: data.is_a?(Hash) ? (data['current_page'] || data['page']) : nil,
    last_page: data.is_a?(Hash) ? (data['last_page'] || data['total_pages']) : nil,
    per_page: data.is_a?(Hash) ? data['per_page'] : nil,
    responses_count: (responses.is_a?(Array) ? responses.length : nil),
    sample_keys: (responses.is_a?(Array) && responses.first.is_a?(Hash) ? responses.first.keys : [])
  }
end

def run_diagnostics
  abort_unless_key!

  print_header('Environment')
  puts "Base URL: #{BASE_URL}"
  puts "API key present: #{env_key && env_key.length > 4 ? 'yes' : 'no'}"

  # Raw API call
  print_header('Raw API: GET /get-responses?page=1&type=sms')
  code, body = get_raw_inbound(page: 1, type: 'sms')
  puts "HTTP: #{code}"
  if code.between?(200, 299)
    raw_payload = parse_json(body)
    raw_summary = summarize_inbound_payload(raw_payload)
    puts "Summary: #{raw_summary.to_json}"
  else
    puts 'Raw request failed; skipping raw summary.'
  end

  # Gem client call
  print_header('Gem Client: get_inbound_messages(page: 1)')
  client = Cellcast.sms(api_key: env_key)
  gem_raw = client.get_inbound_messages(page: 1)

  # gem_raw may be wrapped or raw hash depending on implementation; normalize
  gem_payload = if gem_raw.respond_to?(:to_h)
                  gem_raw.to_h
                else
                  gem_raw
                end
  gem_summary = summarize_inbound_payload(gem_payload)
  puts "Summary: #{gem_summary.to_json}"

  # Compare key expectations the gem uses for InboundMessage mapping
  print_header('Schema Check vs Gem Expectations')
  expected_keys = {
    from: %w[from],
    body: %w[body message],
    received_timestamp: %w[received_at received_date date],
    message_id: %w[message_id messageId id]
  }
  sample_keys = gem_summary[:sample_keys] || []
  expected_keys.each do |field, candidates|
    present = candidates & sample_keys
    puts "Field #{field}: present key(s) => #{present.any? ? present.join(', ') : 'NONE'}"
  end

  # Idempotency check (does a second read change counts?)
  print_header('Repeat Read Check (idempotency)')
  code2, body2 = get_raw_inbound(page: 1, type: 'sms')
  puts "Raw second read HTTP: #{code2}"
  if code2.between?(200, 299)
    raw_payload2 = parse_json(body2)
    raw_summary2 = summarize_inbound_payload(raw_payload2)
    puts "Second read summary: #{raw_summary2.to_json}"
  end

  gem_raw2 = client.get_inbound_messages(page: 1)
  gem_payload2 = gem_raw2.respond_to?(:to_h) ? gem_raw2.to_h : gem_raw2
  gem_summary2 = summarize_inbound_payload(gem_payload2)
  puts "Gem second read summary: #{gem_summary2.to_json}"

  # Final notes
  print_header('Notes')
  puts '- This script only performs GET requests.'
  puts '- If counts drop between reads, the API may treat fetch as a read event.'
  puts '- Use these summaries to adjust the gem parsers and lifecycle handling.'
end

run_diagnostics if __FILE__ == $0
