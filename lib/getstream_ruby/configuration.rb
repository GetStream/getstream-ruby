# frozen_string_literal: true

module GetStreamRuby

  class Configuration

    attr_accessor :api_key, :api_secret, :base_url, :timeout, :logger

    def initialize(api_key: nil, api_secret: nil, base_url: nil, timeout: nil, use_env: true)
      if use_env
        @api_key = api_key || ENV.fetch('STREAM_API_KEY', nil)
        @api_secret = api_secret || ENV.fetch('STREAM_API_SECRET', nil)
        @base_url = base_url || ENV['STREAM_BASE_URL'] || 'https://chat.stream-io-api.com'
        @timeout = timeout || (ENV['STREAM_TIMEOUT'] || 30).to_i
      else
        # Manual configuration only - no environment variables
        @api_key = api_key
        @api_secret = api_secret
        @base_url = base_url || 'https://api.getstream.io/api/v1.0'
        @timeout = timeout || 30
      end

      @logger = nil
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
      )
    end

    # Class method to create configuration with overrides
    def self.with_overrides(overrides = {})
      new(**overrides)
    end

    # Method 1: Manual configuration (no environment variables)
    def self.manual(api_key:, api_secret:, base_url: nil, timeout: nil)
      new(api_key: api_key, api_secret: api_secret,
          base_url: base_url, timeout: timeout, use_env: false)
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

  end

end
