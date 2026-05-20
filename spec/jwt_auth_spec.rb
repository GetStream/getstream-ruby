# frozen_string_literal: true

require 'spec_helper'
require 'jwt'

RSpec.describe 'JWT auth header generation' do

  let(:api_key) { 'test_key' }
  let(:api_secret) { 'test_secret' }
  let(:client) do

    GetStreamRuby.manual(api_key: api_key, api_secret: api_secret)

  end

  describe '#generate_auth_header' do

    it 'returns a non-empty token string' do

      token = client.send(:generate_auth_header)
      expect(token).to be_a(String)
      expect(token).not_to be_empty

    end

    it 'produces a token decodable with the same secret and HS256' do

      token = client.send(:generate_auth_header)
      decoded, header = JWT.decode(token, api_secret, true, { algorithm: 'HS256' })

      expect(header['alg']).to eq('HS256')
      expect(decoded['server']).to eq(true)
      expect(decoded['iat']).to be_a(Integer)
      expect(decoded['iat']).to be_within(5).of(Time.now.to_i)

    end

    it 'produces a token that fails verification with a different secret' do

      token = client.send(:generate_auth_header)

      expect do

        JWT.decode(token, 'wrong_secret', true, { algorithm: 'HS256' })

      end.to raise_error(JWT::VerificationError)

    end

  end

  describe 'configuration validation' do

    it 'rejects a nil api_secret at client construction' do

      expect do

        GetStreamRuby.manual(api_key: api_key, api_secret: nil)

      end.to raise_error(GetStreamRuby::ConfigurationError, /API secret/)

    end

    it 'rejects an empty-string api_secret at client construction' do

      expect do

        GetStreamRuby.manual(api_key: api_key, api_secret: '')

      end.to raise_error(GetStreamRuby::ConfigurationError, /API secret/)

    end

    it 'rejects an empty-string api_key at client construction' do

      expect do

        GetStreamRuby.manual(api_key: '', api_secret: api_secret)

      end.to raise_error(GetStreamRuby::ConfigurationError, /API key/)

    end

  end

end
