# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe 'opt-in retry' do

  def build_client(stubs, retry_config: nil, logger: nil)
    conn = Faraday.new { |b| b.adapter :test, stubs }
    options = { base_url: 'http://localhost', http_client: conn }
    options[:retry_config] = retry_config if retry_config
    options[:logger] = logger if logger
    client = GetStreamRuby::Client.new(api_key: 'key', api_secret: 'secret', **options)
    allow(client).to receive(:sleep)
    client
  end

  def recorder
    io = StringIO.new
    logger = Logger.new(io)
    logger.level = Logger::DEBUG
    [logger, io]
  end

  def enabled(max_attempts: 3, max_backoff: 30.0)
    GetStreamRuby::RetryConfig.new(enabled: true, max_attempts: max_attempts, max_backoff: max_backoff)
  end

  it 'does not retry when disabled (default)' do

    calls = 0
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|

      stub.get(%r{/x}) do

        calls += 1
        [429, { 'Retry-After' => '1' }, '{}']

      end

    end
    client = build_client(stubs)
    expect { client.make_request(:get, '/x') }.to raise_error(GetStreamRuby::RateLimitError)
    expect(calls).to eq(1)

  end

  it 'retries an enabled GET on 429 and honors Retry-After' do

    calls = 0
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|

      stub.get(%r{/x}) do

        calls += 1
        calls == 1 ? [429, { 'Retry-After' => '2' }, '{}'] : [200, {}, '{"ok":true}']

      end

    end
    client = build_client(stubs, retry_config: enabled)
    client.make_request(:get, '/x')
    expect(calls).to eq(2)
    expect(client).to have_received(:sleep).with(2.0)

  end

  it 'never retries POST' do

    calls = 0
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|

      stub.post(%r{/x}) do

        calls += 1
        [429, {}, '{}']

      end

    end
    client = build_client(stubs, retry_config: enabled)
    expect { client.make_request(:post, '/x') }.to raise_error(GetStreamRuby::RateLimitError)
    expect(calls).to eq(1)

  end

  describe 'stale keep-alive retry' do

    it 'retries POST once on Connection reset by peer without retry_config' do

      calls = 0
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|

        stub.post(%r{/x}) do

          calls += 1
          raise Faraday::ConnectionFailed, 'Connection reset by peer' if calls == 1

          [200, {}, '{"ok":true}']

        end

      end
      client = build_client(stubs)
      client.make_request(:post, '/x')
      expect(calls).to eq(2)
      expect(client).not_to have_received(:sleep)

    end

    it 'retries POST once on SSL_read unexpected eof' do

      calls = 0
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|

        stub.post(%r{/x}) do

          calls += 1
          raise Faraday::SSLError, 'SSL_read: unexpected eof while reading' if calls == 1

          [200, {}, '{"ok":true}']

        end

      end
      client = build_client(stubs)
      client.make_request(:post, '/x')
      expect(calls).to eq(2)

    end

    it 'retries POST once on ReadTimeout with a closed TCPSocket' do

      calls = 0
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|

        stub.post(%r{/x}) do

          calls += 1
          raise Faraday::TimeoutError, 'Net::ReadTimeout with #<TCPSocket:(closed)>' if calls == 1

          [200, {}, '{"ok":true}']

        end

      end
      client = build_client(stubs)
      client.make_request(:post, '/x')
      expect(calls).to eq(2)

    end

    it 'does not retry POST on a real read timeout' do

      calls = 0
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|

        stub.post(%r{/x}) do

          calls += 1
          raise Faraday::TimeoutError, 'Net::ReadTimeout'

        end

      end
      client = build_client(stubs)
      expect { client.make_request(:post, '/x') }.to raise_error(GetStreamRuby::TransportError)
      expect(calls).to eq(1)

    end

    it 'does not retry a DNS failure' do

      calls = 0
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|

        stub.post(%r{/x}) do

          calls += 1
          # Faraday needs the SocketError as wrapped_exception for DNS classification.
          raise Faraday::ConnectionFailed.new( # rubocop:disable Style/RaiseArgs
            SocketError.new('getaddrinfo: nodename nor servname provided'),
          )

        end

      end
      client = build_client(stubs)
      expect { client.make_request(:post, '/x') }.to raise_error(GetStreamRuby::TransportError) do |err|

        expect(err.error_type).to eq('dns_failure')

      end
      expect(calls).to eq(1)

    end

    it 'retries a stale connection only once' do

      calls = 0
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|

        stub.post(%r{/x}) do

          calls += 1
          raise Faraday::ConnectionFailed, 'Connection reset by peer'

        end

      end
      client = build_client(stubs)
      expect { client.make_request(:post, '/x') }.to raise_error(GetStreamRuby::TransportError)
      expect(calls).to eq(2)

    end

  end

  it 'never retries an unrecoverable 429' do

    calls = 0
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|

      stub.get(%r{/x}) do

        calls += 1
        [429, {}, '{"message":"nope","unrecoverable":true}']

      end

    end
    client = build_client(stubs, retry_config: enabled)
    expect { client.make_request(:get, '/x') }.to raise_error(GetStreamRuby::RateLimitError)
    expect(calls).to eq(1)

  end

  it 'retries a transport error' do

    calls = 0
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|

      stub.get(%r{/x}) do

        calls += 1
        raise Faraday::TimeoutError if calls == 1

        [200, {}, '{"ok":true}']

      end

    end
    client = build_client(stubs, retry_config: enabled(max_backoff: 0.001))
    client.make_request(:get, '/x')
    expect(calls).to eq(2)

  end

  it 'surfaces the last error after max attempts' do

    calls = 0
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|

      stub.get(%r{/x}) do

        calls += 1
        [429, {}, '{}']

      end

    end
    client = build_client(stubs, retry_config: enabled(max_attempts: 3, max_backoff: 0.001))
    expect { client.make_request(:get, '/x') }.to raise_error(GetStreamRuby::RateLimitError)
    expect(calls).to eq(3)

  end

  it 'clamps Retry-After to max_backoff' do

    calls = 0
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|

      stub.get(%r{/x}) do

        calls += 1
        calls == 1 ? [429, { 'Retry-After' => '600' }, '{}'] : [200, {}, '{"ok":true}']

      end

    end
    client = build_client(stubs, retry_config: enabled(max_backoff: 30.0))
    client.make_request(:get, '/x')
    expect(client).to have_received(:sleep).with(30.0)

  end

  it 'jitters the backoff for a non-retry_after failure within [0, min(max_backoff, 2**attempt)]' do

    calls = 0
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|

      stub.get(%r{/x}) do

        calls += 1
        calls == 1 ? [429, {}, '{}'] : [200, {}, '{"ok":true}']

      end

    end
    client = build_client(stubs, retry_config: enabled(max_backoff: 30.0))
    client.make_request(:get, '/x')
    # attempt 0 => ceiling = min(30.0, 2**0) = 1.0
    expect(client).to have_received(:sleep) do |delay|

      expect(delay).to be >= 0.0
      expect(delay).to be <= 1.0

    end

  end

  it 'never retries make_multipart_request (POST-only upload path)' do

    calls = 0
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|

      stub.post(%r{/upload}) do

        calls += 1
        [429, {}, '{}']

      end

    end
    client = build_client(stubs, retry_config: enabled)
    file = GetStream::Generated::Models::FileUploadRequest.new(file: __FILE__)
    expect { client.send(:make_multipart_request, :post, '/upload', {}, file) }
      .to raise_error(GetStreamRuby::RateLimitError)
    expect(calls).to eq(1)

  end

  describe 'retry-attempt logging' do

    it 'logs error.type on a transport-error retry' do

      calls = 0
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|

        stub.get(%r{/x}) do

          calls += 1
          raise Faraday::TimeoutError if calls == 1

          [200, {}, '{"ok":true}']

        end

      end
      logger, io = recorder
      client = build_client(stubs, retry_config: enabled(max_backoff: 0.001), logger: logger)
      client.make_request(:get, '/x')

      retry_line = io.string.lines.find { |l| l.include?('retry.attempt=1') }
      expect(retry_line).not_to be_nil
      expect(retry_line).to include('error.type=timeout')

    end

    it 'omits error.type and any rate_limited flag on a 429 retry' do

      calls = 0
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|

        stub.get(%r{/x}) do

          calls += 1
          calls == 1 ? [429, {}, '{}'] : [200, {}, '{"ok":true}']

        end

      end
      logger, io = recorder
      client = build_client(stubs, retry_config: enabled(max_backoff: 0.001), logger: logger)
      client.make_request(:get, '/x')

      retry_line = io.string.lines.find { |l| l.include?('retry.attempt=1') }
      expect(retry_line).not_to be_nil
      expect(retry_line).not_to include('error.type')
      expect(retry_line).not_to include('rate_limited')

    end

  end

end
