# frozen_string_literal: true

require 'spec_helper'
require 'jwt'

# Server auth token (JWT) generation. Guards against the clock-skew 401
# regression: `iat` is backdated so a caller whose clock is marginally ahead of
# the server does not get intermittently rejected with
# "token used before issue at (iat)".
RSpec.describe 'server auth token' do

  let(:secret) { 's' }
  let(:client) { GetStreamRuby.manual(api_key: 'k', api_secret: secret) }

  def decode_payload
    header = client.send(:generate_auth_header)
    JWT.decode(header, secret, true, algorithm: 'HS256').first
  end

  it 'signs a server token with the server claim' do

    expect(decode_payload['server']).to be(true)

  end

  it 'backdates iat by AUTH_IAT_LEEWAY_SECONDS to absorb client/server clock skew' do

    before = Time.now.to_i
    iat = decode_payload['iat']
    after = Time.now.to_i

    # iat must sit at least the leeway behind "now" at signing time, and never
    # ahead of it, so the server never sees a future-dated token.
    expect(iat).to be <= (before - GetStreamRuby::Client::AUTH_IAT_LEEWAY_SECONDS)
    expect(iat).to be >= (after - GetStreamRuby::Client::AUTH_IAT_LEEWAY_SECONDS - 1)

  end

  it 'keeps the leeway positive so the backdate is actually applied' do

    expect(GetStreamRuby::Client::AUTH_IAT_LEEWAY_SECONDS).to be > 0

  end

end
