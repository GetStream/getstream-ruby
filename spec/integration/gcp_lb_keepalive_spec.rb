# frozen_string_literal: true

require 'rspec'
require 'uri'
require_relative 'chat_test_helpers'

# CHA-4943: GCP SSL-proxy LBs close idle TLS around ~30s. The SDK pool must
# drop connections before that, otherwise the next request raises
# GetStreamRuby::TransportError (SSL_read: unexpected eof while reading).
#
# Skipped unless STREAM_BASE_URL is a GCP edge hostname so default CI (AWS /
# geo-routed chat.stream-io-api.com) does not wait 35s for a no-op.
RSpec.describe 'GCP load balancer keep-alive', type: :integration do

  include ChatTestHelpers

  # Match on the parsed host suffix rather than a substring so a URL like
  # https://gcp.stream-io-api.com.example.com does not slip through.
  def gcp_edge_base_url?
    host = URI(ENV.fetch('STREAM_BASE_URL', '')).host.to_s
    host.end_with?('.gcp.stream-io-api.com')
  rescue URI::InvalidURIError
    false
  end

  before(:all) do

    skip 'STREAM_BASE_URL must be a *.gcp.stream-io-api.com edge' unless gcp_edge_base_url?
    init_chat_client

  end

  after(:all) do

    cleanup_chat_resources if gcp_edge_base_url?

  end

  it 'reuses the pooled client after 35s idle without TLS EOF' do

    ids, = create_test_users(1)
    sleep ENV.fetch('STREAM_GCP_LB_IDLE_SLEEP', '35').to_i
    expect { create_test_users(1) }.not_to raise_error
    expect(ids).not_to be_empty

  end

end
