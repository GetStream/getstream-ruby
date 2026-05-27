# frozen_string_literal: true

require 'spec_helper'
require 'faraday/net_http_persistent'

# CHA-2956 connection pooling spec.
RSpec.describe 'CHA-2956 connection pooling' do

  # Capture the args/kwargs of the last `conn.adapter` call made while the
  # block runs. Intercepts the public Faraday::RackBuilder#adapter API (the
  # same call the client makes) rather than the handler's internal @args
  # ivar, whose layout changed between Faraday 2.8 (kwargs in @args) and 2.9+
  # (kwargs in a separate @kwargs), which made the old introspection nil in CI.
  def capture_adapter_call
    captured = { args: [], kwargs: {} }
    allow_any_instance_of(Faraday::RackBuilder).to receive(:adapter).and_wrap_original do |orig, *args, **kwargs, &blk|

      captured[:args] = args
      captured[:kwargs] = kwargs
      orig.call(*args, **kwargs, &blk)

    end
    yield
    captured
  end

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

      captured = capture_adapter_call { GetStreamRuby.manual(api_key: 'k', api_secret: 's') }
      expect(captured[:args].first).to eq(:net_http_persistent)
      expect(captured[:kwargs]).to include(pool_size: 5)

    end

  end

  describe 'individual knob overrides' do

    it 'honors max_conns_per_host:' do

      captured = capture_adapter_call do

        GetStreamRuby.manual(api_key: 'k', api_secret: 's', max_conns_per_host: 17)

      end
      expect(captured[:kwargs]).to include(pool_size: 17)

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

  describe 'per-call request_timeout override' do

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

  describe 'escape hatch: http_client' do

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

  describe 'escape hatch: faraday_adapter' do

    it 'uses the custom adapter symbol and does NOT apply pool_size' do

      captured = capture_adapter_call do

        GetStreamRuby.manual(
          api_key: 'k', api_secret: 's',
          faraday_adapter: :net_http,
          max_conns_per_host: 17 # MUST be ignored
        )

      end

      expect(captured[:args].first).to eq(:net_http)
      expect(captured[:kwargs]).not_to include(pool_size: 17)

    end

  end

  describe 'adapter fallback' do

    # A bogus adapter symbol forces configure_adapter into its rescue, which
    # falls back to Faraday.default_adapter and disables pooling.
    let(:bogus) { :bogus_xyz_adapter }

    it 'warns via a $stdout logger when no logger is configured (never silent)' do

      build = -> { GetStreamRuby.manual(api_key: 'k', api_secret: 's', faraday_adapter: bogus) }
      expect(&build).to output(/Falling back to .*could not configure net_http_persistent/).to_stdout

    end

    it 'warns on the configured logger when one is supplied' do

      log_io = StringIO.new
      logger = Logger.new(log_io).tap { |l| l.level = Logger::WARN }
      GetStreamRuby.manual(api_key: 'k', api_secret: 's', faraday_adapter: bogus, logger: logger)
      expect(log_io.string).to include('WARN').and include('Falling back to')

    end

    it 'builds the default adapter, not the requested-but-failed one' do

      client = GetStreamRuby.manual(api_key: 'k', api_secret: 's', faraday_adapter: bogus)
      handler = client.instance_variable_get(:@connection).builder.adapter
      expect(handler.klass).to eq(Faraday::Adapter.lookup_middleware(Faraday.default_adapter))

    end

    it 'reports the EFFECTIVE adapter in the INFO log, not the requested one' do

      log_io = StringIO.new
      logger = Logger.new(log_io).tap { |l| l.level = Logger::INFO }
      GetStreamRuby.manual(api_key: 'k', api_secret: 's', faraday_adapter: bogus, logger: logger)
      info_lines = log_io.string.lines.select { |l| l.include?('INFO') }
      expect(info_lines.size).to eq(1)
      expect(info_lines.first).to include("faraday_adapter=#{Faraday.default_adapter}")
      expect(info_lines.first).not_to include("faraday_adapter=#{bogus}")

    end

  end

  describe 'INFO log on construction' do

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
