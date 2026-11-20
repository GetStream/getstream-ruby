# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'query parameters' do

  it 'sends a list value as comma-separated values' do

    query = nil
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|

      stub.get(%r{/x}) do |env|

        query = URI.decode_www_form(env.url.query).to_h
        [200, {}, '{}']

      end

    end
    conn = Faraday.new { |b| b.adapter :test, stubs }
    options = { base_url: 'http://localhost', http_client: conn }
    client = GetStreamRuby::Client.new(api_key: 'key', api_secret: 'secret', **options)
    client.make_request(:get, '/x', query_params: { product: %w[chat video] })
    expect(query['product']).to eq('chat,video')

  end

end
