# frozen_string_literal: true

module GetStreamRuby

  class Configuration

    attr_accessor :api_key, :api_secret, :base_url, :timeout, :logger, :faraday_adapter, :faraday_adapter_options,
                  :connection_keep_alive

    def initialize(api_key: nil, api_secret: nil, use_env: true, **options)
      base_url = options[:base_url]
      timeout = options[:timeout]
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
        @timeout = timeout || (ENV['STREAM_TIMEOUT'] || 30).to_i
      else
        # Manual configuration only - no environment variables
        @api_key = api_key
        @api_secret = api_secret
        @base_url = base_url || 'https://chat.stream-io-api.com'
        @timeout = timeout || 30
      end

      @faraday_adapter = (faraday_adapter || ENV.fetch('STREAM_FARADAY_ADAPTER', nil))&.to_sym
      @faraday_adapter_options = faraday_adapter_options || default_adapter_options
      @connection_keep_alive = if connection_keep_alive.nil?
                                 ENV.fetch('STREAM_CONNECTION_KEEP_ALIVE', 'true') == 'true'
                               else
                                 connection_keep_alive
                               end
      @logger = nil
    end

    def valid?
      !blank?(api_key) && !blank?(api_secret)
    end

    def validate!
      raise ConfigurationError, 'API key is required' if blank?(api_key)
      raise ConfigurationError, 'API secret is required' if blank?(api_secret)
    end

    def dup
      Configuration.new(
        api_key: @api_key,
        api_secret: @api_secret,
        base_url: @base_url,
        timeout: @timeout,
        faraday_adapter: @faraday_adapter,
        faraday_adapter_options: @faraday_adapter_options.dup,
        connection_keep_alive: @connection_keep_alive,
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

    def blank?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end

  end

end
