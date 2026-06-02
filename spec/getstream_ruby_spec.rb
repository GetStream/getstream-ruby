# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GetStreamRuby do

  before do

    # Clear cached clients
    GetStreamRuby.instance_variable_set(:@env_client, nil)
    GetStreamRuby.instance_variable_set(:@env_vars_client, nil)

  end

  describe '.manual' do

    it 'creates a client with manual configuration' do

      client = GetStreamRuby.manual(
        api_key: 'manual_key',
        api_secret: 'manual_secret',
      )
      expect(client).to be_a(GetStreamRuby::Client)
      expect(client.configuration.api_key).to eq('manual_key')
      expect(client.configuration.api_secret).to eq('manual_secret')
      expect(client.configuration.faraday_adapter).to be_nil
      expect(client.configuration.faraday_adapter_options).to eq({})
      expect(client.configuration.connection_keep_alive).to eq(true)
      expect(client.configuration.max_conns_per_host).to eq(5)
      expect(client.configuration.idle_timeout).to eq(55)
      expect(client.configuration.connect_timeout).to eq(10)
      expect(client.configuration.request_timeout).to eq(30)
      expect(client.configuration.http_client).to be_nil
      # Backwards-compat: timeout: kwarg is an alias for request_timeout:.
      expect(client.configuration.timeout).to eq(30)

    end

    it 'creates a client with custom faraday adapter settings' do

      client = GetStreamRuby.manual(
        api_key: 'manual_key',
        api_secret: 'manual_secret',
        faraday_adapter: :net_http,
        faraday_adapter_options: {},
        connection_keep_alive: false,
      )
      expect(client.configuration.faraday_adapter).to eq(:net_http)
      expect(client.configuration.faraday_adapter_options).to eq({})
      expect(client.configuration.connection_keep_alive).to eq(false)

    end

  end

  describe '.env' do

    it 'creates a client with .env file' do

      ENV['STREAM_API_KEY'] = 'env_key'
      ENV['STREAM_API_SECRET'] = 'env_secret'

      client = GetStreamRuby.env
      expect(client).to be_a(GetStreamRuby::Client)
      expect(client.configuration.api_key).to eq('env_key')

    end

  end

  describe '.env_vars' do

    it 'creates a client with environment variables' do

      ENV['STREAM_API_KEY'] = 'vars_key'
      ENV['STREAM_API_SECRET'] = 'vars_secret'

      client = GetStreamRuby.env_vars
      expect(client).to be_a(GetStreamRuby::Client)
      expect(client.configuration.api_key).to eq('vars_key')

    end

  end

end
