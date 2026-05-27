# frozen_string_literal: true

require 'logger'

module GetStreamRuby

  class Configuration

    attr_accessor :api_key, :api_secret, :base_url, :timeout, :logger, :faraday_adapter, :faraday_adapter_options,
                  :connection_keep_alive, :max_conns_per_host, :idle_timeout, :connect_timeout,
                  :request_timeout, :http_client

    def initialize(api_key: nil, api_secret: nil, use_env: true, **options)
      http_options = options[:http_options] || {}

      assign_credentials_and_url(api_key, api_secret, options[:base_url], use_env: use_env)
      assign_timeouts_and_pool(options, use_env: use_env)
      assign_adapter(options, http_options)
      assign_keep_alive(options, http_options)

      # Keep @timeout in sync with @request_timeout for backwards compatibility.
      @timeout = @request_timeout
      @http_client = options[:http_client]
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

    # Emit a single INFO line listing the 5 effective pool knobs plus the
    # active escape hatch (CHA-2956). If no logger
    # is supplied, a default $stdout INFO logger is used.
    def log_pool_config_to(logger)
      logger ||= Logger.new($stdout).tap { |l| l.level = Logger::INFO }
      flag = @http_client ? 'user_http_client=true' : 'user_http_client=false'
      adapter_label = if @http_client
                        'user-supplied'
                      elsif @faraday_adapter
                        @faraday_adapter.to_s
                      else
                        'default'
                      end
      fmt = 'connection pool: max_conns_per_host=%<m>d idle_timeout=%<i>d ' \
            'connect_timeout=%<c>d request_timeout=%<r>d %<flag>s faraday_adapter=%<a>s'
      logger.info(
        format(
          fmt,
          m: @max_conns_per_host, i: @idle_timeout, c: @connect_timeout,
          r: @request_timeout, flag: flag, a: adapter_label
        ),
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

    def assign_credentials_and_url(api_key, api_secret, base_url, use_env:)
      if use_env
        @api_key = api_key || ENV.fetch('STREAM_API_KEY', nil)
        @api_secret = api_secret || ENV.fetch('STREAM_API_SECRET', nil)
        @base_url = base_url || ENV.fetch('STREAM_BASE_URL', nil) || 'https://chat.stream-io-api.com'
      else
        @api_key = api_key
        @api_secret = api_secret
        @base_url = base_url || 'https://chat.stream-io-api.com'
      end
    end

    def assign_timeouts_and_pool(options, use_env:)
      timeout = options[:timeout]
      request_timeout = options[:request_timeout]
      max_conns_per_host = options[:max_conns_per_host]
      idle_timeout = options[:idle_timeout]
      connect_timeout = options[:connect_timeout]

      if use_env
        env_request_timeout = ENV.fetch('STREAM_REQUEST_TIMEOUT', nil) || ENV.fetch('STREAM_TIMEOUT', nil)
        @request_timeout = (request_timeout || timeout || env_request_timeout || 30).to_i
        @max_conns_per_host = (max_conns_per_host || ENV.fetch('STREAM_MAX_CONNS_PER_HOST', nil) || 5).to_i
        @idle_timeout = (idle_timeout || ENV.fetch('STREAM_IDLE_TIMEOUT', nil) || 55).to_i
        @connect_timeout = (connect_timeout || ENV.fetch('STREAM_CONNECT_TIMEOUT', nil) || 10).to_i
      else
        @request_timeout = (request_timeout || timeout || 30).to_i
        @max_conns_per_host = (max_conns_per_host || 5).to_i
        @idle_timeout = (idle_timeout || 55).to_i
        @connect_timeout = (connect_timeout || 10).to_i
      end
    end

    def assign_adapter(options, http_options)
      faraday_adapter = options[:faraday_adapter] || http_options[:faraday_adapter]
      faraday_adapter_options = options[:faraday_adapter_options] || http_options[:faraday_adapter_options]
      @faraday_adapter = (faraday_adapter || ENV.fetch('STREAM_FARADAY_ADAPTER', nil))&.to_sym
      @faraday_adapter_options = faraday_adapter_options || default_adapter_options
    end

    def assign_keep_alive(options, http_options)
      connection_keep_alive = if options.key?(:connection_keep_alive)
                                options[:connection_keep_alive]
                              else
                                http_options[:connection_keep_alive]
                              end
      @connection_keep_alive = if connection_keep_alive.nil?
                                 ENV.fetch('STREAM_CONNECTION_KEEP_ALIVE', 'true') == 'true'
                               else
                                 connection_keep_alive
                               end
    end

  end

end
