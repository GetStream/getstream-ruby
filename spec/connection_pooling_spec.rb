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

end
