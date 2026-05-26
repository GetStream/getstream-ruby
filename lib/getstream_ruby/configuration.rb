# frozen_string_literal: true

module GetStreamRuby

  class Configuration

    attr_accessor :api_key, :api_secret, :base_url, :timeout, :logger, :faraday_adapter, :faraday_adapter_options,
                  :connection_keep_alive, :max_conns_per_host, :idle_timeout, :connect_timeout,
                  :request_timeout, :http_client

    def initialize(api_key: nil, api_secret: nil, use_env: true, **options)
      base_url = options[:base_url]
      timeout = options[:timeout]
      request_timeout = options[:request_timeout]
      max_conns_per_host = options[:max_conns_per_host]
      idle_timeout = options[:idle_timeout]
      connect_timeout = options[:connect_timeout]
      http_client = options[:http_client]
      http_options = options[:http_options] || {}
      faraday_adapter = options[:faraday_adapter] || http_options[:faraday_adapter]
      faraday_adapter_options = options[:faraday_adapter_options] || http_options[:faraday_adapter_options]
      connection_keep_alive = if options.key?(:connection_keep_alive)
                                options[:connection_keep_alive]
                              else
                                http_options[:connection_keep_alive]
                              end

      if use_env
        @api_key = api_key || ENV.fetch('STREAM_API_KEY', nil)
        @api_secret = api_secret || ENV.fetch('STREAM_API_SECRET', nil)
        @base_url = base_url || ENV['STREAM_BASE_URL'] || 'https://chat.stream-io-api.com'
        env_request_timeout = ENV['STREAM_REQUEST_TIMEOUT'] || ENV['STREAM_TIMEOUT']
        @request_timeout = (request_timeout || timeout || env_request_timeout || 30).to_i
        @max_conns_per_host = (max_conns_per_host || ENV['STREAM_MAX_CONNS_PER_HOST'] || 5).to_i
        @idle_timeout = (idle_timeout || ENV['STREAM_IDLE_TIMEOUT'] || 55).to_i
        @connect_timeout = (connect_timeout || ENV['STREAM_CONNECT_TIMEOUT'] || 10).to_i
      else
        # Manual configuration only - no environment variables
        @api_key = api_key
        @api_secret = api_secret
        @base_url = base_url || 'https://chat.stream-io-api.com'
        @request_timeout = (request_timeout || timeout || 30).to_i
        @max_conns_per_host = (max_conns_per_host || 5).to_i
        @idle_timeout = (idle_timeout || 55).to_i
        @connect_timeout = (connect_timeout || 10).to_i
      end

      # Keep @timeout in sync with @request_timeout for backwards compatibility.
      @timeout = @request_timeout

      @http_client = http_client
      @faraday_adapter = (faraday_adapter || ENV.fetch('STREAM_FARADAY_ADAPTER', nil))&.to_sym
      @faraday_adapter_options = faraday_adapter_options || default_adapter_options
      @connection_keep_alive = if connection_keep_alive.nil?
                                 ENV.fetch('STREAM_CONNECTION_KEEP_ALIVE', 'true') == 'true'
                               else
                                 connection_keep_alive
                               end
      @logger = options[:logger]
    end

    def valid?
      api_key && api_secret
    end

    def validate!
      raise ConfigurationError, 'API key is required' unless api_key
      raise ConfigurationError, 'API secret is required' unless api_secret
    end

    def dup
      Configuration.new(
        api_key: @api_key,
        api_secret: @api_secret,
        base_url: @base_url,
        timeout: @timeout,
        request_timeout: @request_timeout,
        max_conns_per_host: @max_conns_per_host,
        idle_timeout: @idle_timeout,
        connect_timeout: @connect_timeout,
        http_client: @http_client,
        faraday_adapter: @faraday_adapter,
        faraday_adapter_options: @faraday_adapter_options.dup,
        connection_keep_alive: @connection_keep_alive,
        logger: @logger,
      )
    end

    # Class method to create configuration with overrides
    def self.with_overrides(overrides = {})
      new(**overrides)
    end

    # Method 1: Manual configuration (no environment variables)
    def self.manual(api_key:, api_secret:, **options)
      new(api_key: api_key, api_secret: api_secret, use_env: false, **options)
    end

    # Method 2: .env file (loads .env file via dotenv gem, falls back to env vars)
    def self.from_env
      require 'dotenv/load' if File.exist?('.env') && !File.empty?('.env') && !defined?(Dotenv)
      new(use_env: true)
    end

    # Method 3: Environment variables (no .env file, direct system env)
    def self.from_system_env
      new(use_env: true)
    end

    private

    def default_adapter_options
      {}
    end

  end

end
