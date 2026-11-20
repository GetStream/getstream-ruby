# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'query parameters' do

  def sent_query
    query = nil
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|

      stub.get(%r{/}) do |env|

        query = URI.decode_www_form(env.url.query).to_h
        [200, {}, '{}']

      end

    end
    conn = Faraday.new { |b| b.adapter :test, stubs }
    options = { base_url: 'http://localhost', http_client: conn }
    yield GetStreamRuby::Client.new(api_key: 'key', api_secret: 'secret', **options)
    query
  end

  it 'sends a list value as comma-separated values' do

    query = sent_query { |c| c.make_request(:get, '/x', query_params: { product: %w[chat video] }) }
    expect(query['product']).to eq('chat,video')

  end

  it 'keeps a list element containing + or & intact' do

    query = sent_query { |c| c.make_request(:get, '/x', query_params: { ids: ['m+1', 'a&b=c', 'z'] }) }
    expect(query).to eq('ids' => 'm+1,a&b=c,z', 'api_key' => 'key')

  end

  it 'sends a list of models as JSON and keeps later params' do

    sort = [GetStream::Generated::Models::SortParamRequest.new(field: 'created_at', direction: -1)]
    query = sent_query do |c|

      c.chat.get_pinned_messages(
        'messaging', 'c1', 5, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 'u1', sort, %w[a b]
      )

    end
    expect(JSON.parse(query['sort'])).to eq([{ 'field' => 'created_at', 'direction' => -1 }])
    expect(query['member_custom_include']).to eq('a,b')
    expect(query['user_id']).to eq('u1')

  end

  it 'sends a Hash value as JSON' do

    query = sent_query { |c| c.make_request(:get, '/x', query_params: { filter_conditions: { 'a' => 1 } }) }
    expect(JSON.parse(query['filter_conditions'])).to eq('a' => 1)

  end

  it 'sends a DateTime as RFC 3339 with its offset' do

    at = DateTime.new(2026, 11, 20, 10, 0, 0, '+01:00')
    query = sent_query { |c| c.make_request(:get, '/x', query_params: { pinned_at_after: at }) }
    expect(query['pinned_at_after']).to eq('2026-11-20T10:00:00.000000000+01:00')

  end

end
