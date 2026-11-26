# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GetStreamRuby::LogRedaction do

  describe '.redact_json_body recursive redaction' do

    it 'redacts nested and pattern-matched sensitive keys in hashes and arrays' do

      payload = JSON.generate(
        access_token: 'tok-123',
        keep: 'visible',
        storage: {
          s3_secret: 'aws-secret-value',
          firebase_credentials: '{"private_key":"pem"}',
          bucket: 'my-bucket',
        },
        items: [{ apn_auth_key: 'p8-key', name: 'ios' }],
      )

      redacted = described_class.redact_json_body(payload)
      expect(redacted).not_to include('tok-123', 'aws-secret-value', 'p8-key')

      parsed = JSON.parse(redacted)
      expect(parsed['access_token']).to eq('<redacted>')
      expect(parsed['keep']).to eq('visible')
      expect(parsed['storage']['s3_secret']).to eq('<redacted>')
      expect(parsed['storage']['firebase_credentials']).to eq('<redacted>')
      expect(parsed['storage']['bucket']).to eq('my-bucket')
      expect(parsed['items'][0]['apn_auth_key']).to eq('<redacted>')
      expect(parsed['items'][0]['name']).to eq('ios')

    end

  end

end
