# frozen_string_literal: true

require 'spec_helper'
require 'faraday/net_http_persistent'

# CHA-2956 connection pooling spec.
RSpec.describe 'CHA-2956 connection pooling' do

  describe 'defaults' do

    let(:client) { GetStreamRuby.manual(api_key: 'k', api_secret: 's') }

    it 'uses net_http_persistent as the default adapter' do

      handler = client.instance_variable_get(:@connection).builder.adapter
      expect(handler.klass).to eq(Faraday::Adapter::NetHttpPersistent)

    end

    it 'sets request_timeout and connect_timeout on Faraday options' do

      conn = client.instance_variable_get(:@connection)
      expect(conn.options.timeout).to eq(30)
      expect(conn.options.open_timeout).to eq(10)

    end

    it 'passes pool_size=5 to the net_http_persistent adapter' do

      handler = client.instance_variable_get(:@connection).builder.adapter
      kwargs = handler.instance_variable_get(:@args).last
      expect(kwargs).to include(pool_size: 5)

    end

  end

  describe 'individual knob overrides' do

    it 'honors max_conns_per_host:' do

      client = GetStreamRuby.manual(api_key: 'k', api_secret: 's', max_conns_per_host: 17)
      handler = client.instance_variable_get(:@connection).builder.adapter
      expect(handler.instance_variable_get(:@args).last).to include(pool_size: 17)

    end

    it 'honors connect_timeout:' do

      client = GetStreamRuby.manual(api_key: 'k', api_secret: 's', connect_timeout: 3)
      expect(client.instance_variable_get(:@connection).options.open_timeout).to eq(3)

    end

    it 'honors request_timeout:' do

      client = GetStreamRuby.manual(api_key: 'k', api_secret: 's', request_timeout: 7)
      expect(client.instance_variable_get(:@connection).options.timeout).to eq(7)

    end

    it 'keeps timeout: as a backwards-compat alias for request_timeout:' do

      client = GetStreamRuby.manual(api_key: 'k', api_secret: 's', timeout: 11)
      expect(client.configuration.request_timeout).to eq(11)
      expect(client.instance_variable_get(:@connection).options.timeout).to eq(11)

    end

  end

  describe 'per-call request_timeout override (§5.2)' do

    let(:stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:client) do

      c = GetStreamRuby.manual(
        api_key: 'k', api_secret: 's',
        base_url: 'https://chat.stream-io-api.test',
        request_timeout: 30
      )
      test_conn = Faraday.new(url: c.configuration.base_url) do |conn|

        conn.request :multipart
        conn.response :json, content_type: /\bjson$/
        conn.adapter :test, stubs

      end
      c.instance_variable_set(:@connection, test_conn)
      c

    end

    it 'overrides per-request timeout for a single call without mutating the client' do

      captured = nil
      stubs.get('/api/v2/probe') do |env|

        captured = env
        [200, { 'Content-Type' => 'application/json' }, '{}']

      end

      client.make_request(:get, '/api/v2/probe', request_timeout: 5)

      expect(captured.request.timeout).to eq(5)
      expect(client.configuration.request_timeout).to eq(30)

    end

  end

  describe 'escape hatch: http_client (§7)' do

    it 'uses the user-supplied Faraday::Connection as-is' do

      custom = Faraday.new(url: 'https://example.invalid') { |c| c.adapter :test }
      client = GetStreamRuby.manual(
        api_key: 'k', api_secret: 's',
        http_client: custom,
        # All ignored:
        max_conns_per_host: 99,
        idle_timeout: 99,
        connect_timeout: 99,
        request_timeout: 99
      )

      expect(client.instance_variable_get(:@connection)).to be(custom)
      expect(custom.builder.adapter.klass).to eq(Faraday::Adapter::Test)

    end

  end

  describe 'escape hatch: faraday_adapter (§7)' do

    it 'uses the custom adapter symbol and does NOT apply pool_size' do

      client = GetStreamRuby.manual(
        api_key: 'k', api_secret: 's',
        faraday_adapter: :net_http,
        max_conns_per_host: 17 # MUST be ignored
      )

      handler = client.instance_variable_get(:@connection).builder.adapter
      expect(handler.klass).to eq(Faraday::Adapter::NetHttp)
      kwargs = handler.instance_variable_get(:@args).last
      kwargs = {} unless kwargs.is_a?(Hash)
      expect(kwargs).not_to include(pool_size: 17)

    end

  end

  describe 'INFO log on construction (§8)' do

    let(:log_io) { StringIO.new }
    let(:logger) { Logger.new(log_io).tap { |l| l.level = Logger::INFO } }

    it 'emits exactly one INFO line listing the 5 effective values' do

      GetStreamRuby.manual(api_key: 'k', api_secret: 's', logger: logger)
      info_lines = log_io.string.lines.select { |l| l.include?('INFO') }
      expect(info_lines.size).to eq(1)
      line = info_lines.first
      expect(line).to include('connection pool')
      expect(line).to include('max_conns_per_host=5')
      expect(line).to include('idle_timeout=55')
      expect(line).to include('connect_timeout=10')
      expect(line).to include('request_timeout=30')
      expect(line).to include('user_http_client=false')
      expect(line).to include('faraday_adapter=default')

    end

    it 'reports user_http_client=true when http_client is supplied' do

      custom = Faraday.new(url: 'https://example.invalid') { |c| c.adapter :test }
      GetStreamRuby.manual(api_key: 'k', api_secret: 's', logger: logger, http_client: custom)
      expect(log_io.string).to include('user_http_client=true')

    end

    it 'reports the adapter symbol when faraday_adapter is supplied' do

      GetStreamRuby.manual(api_key: 'k', api_secret: 's', logger: logger, faraday_adapter: :net_http)
      expect(log_io.string).to include('faraday_adapter=net_http')

    end

  end

end
