# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GetStreamRuby::Resources::Feed do

  let(:client) { instance_double(GetStreamRuby::Client) }
  let(:feed) { described_class.new(client) }

  it 'percent-encodes special characters in feed_slug and user_id' do
    expect(client).to receive(:post).with(
      '/feed/user%20feed/..%2Fother%3Fadmin%3D1%23frag/',
      hash_including(id: 'user feed:../other?admin=1#frag'),
    )

    feed.create('user feed', '../other?admin=1#frag')
  end

  ['', '.', '..', nil].each do |bad|
    it "rejects invalid path segment #{bad.inspect}" do
      expect(client).not_to receive(:post)
      expect { feed.create('user', bad) }.to raise_error(ArgumentError)
      expect { feed.create(bad, 'alice') }.to raise_error(ArgumentError)
    end
  end

end
