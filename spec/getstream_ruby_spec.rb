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
