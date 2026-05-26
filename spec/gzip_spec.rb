# frozen_string_literal: true

require 'spec_helper'

require 'faraday'
require 'json'
require 'stringio'
require 'zlib'

# CHA-2964 — verify that the SDK's default Faraday connection both advertises
# gzip via the Accept-Encoding request header and transparently decodes a
# gzip-encoded JSON response body. Driven through the public Client#post entry
# point with Faraday's :test adapter so the full middleware stack runs.
RSpec.describe 'Gzip request/response handling' do

  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:client) do

    c = GetStreamRuby.manual(
      api_key: 'test_key',
      api_secret: 'test_secret',
      base_url: 'https://chat.stream-io-api.test',
    )
    # Replace the production connection with one that wires the same middleware
    # stack but uses Faraday's :test adapter so we can stub outgoing requests.
    # We mirror the production middleware order from Client#build_connection so
    # this spec exercises the real gzip-request middleware.
    test_conn = Faraday.new(url: c.configuration.base_url) do |conn|

      conn.request :multipart
      conn.response :json, content_type: /\bjson$/
      conn.request :gzip
      conn.adapter :test, stubs

    end
    c.instance_variable_set(:@connection, test_conn)
    c

  end

  def gzip(payload)
    io = StringIO.new
    io.set_encoding('ASCII-8BIT')
    gz = Zlib::GzipWriter.new(io)
    gz.write(payload)
    gz.close
    io.string
  end

  it 'sends an Accept-Encoding header that advertises gzip' do

    captured_request = nil
    stubs.post('/some-path') do |env|

      captured_request = env
      [200, { 'Content-Type' => 'application/json' }, '{}']

    end

    client.post('/some-path', { hello: 'world' })

    expect(captured_request).not_to be_nil
    expect(captured_request.request_headers['Accept-Encoding']).to include('gzip')

  end

  it 'transparently decodes a gzipped JSON response body' do

    expected_body = { 'message' => 'decoded', 'count' => 42 }
    compressed = gzip(expected_body.to_json)

    stubs.post('/echo') do

      [
        200,
        {
          'Content-Type' => 'application/json',
          'Content-Encoding' => 'gzip',
        },
        compressed,
      ]

    end

    response = client.post('/echo', {})

    expect(response.to_h).to eq(expected_body)
    expect(response.message).to eq('decoded')
    expect(response.count).to eq(42)

  end

end
