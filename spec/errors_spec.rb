# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'time'

# Error handling spec.
RSpec.describe 'GetStreamRuby error handling' do

  describe 'class hierarchy' do

    it 'StreamError descends from StandardError' do

      expect(GetStreamRuby::StreamError.ancestors).to include(StandardError)

    end

    it 'ApiError descends from StreamError' do

      expect(GetStreamRuby::ApiError.ancestors).to include(GetStreamRuby::StreamError)

    end

    it 'RateLimitError descends from ApiError (and from StreamError)' do

      expect(GetStreamRuby::RateLimitError.ancestors).to include(GetStreamRuby::ApiError)
      expect(GetStreamRuby::RateLimitError.ancestors).to include(GetStreamRuby::StreamError)

    end

    it 'TransportError descends from StreamError' do

      expect(GetStreamRuby::TransportError.ancestors).to include(GetStreamRuby::StreamError)

    end

    it 'TaskError descends from StreamError' do

      expect(GetStreamRuby::TaskError.ancestors).to include(GetStreamRuby::StreamError)

    end

    it 'keeps the legacy GetStreamRuby::Error alias as a backward-compat catch-all' do

      expect(GetStreamRuby::Error).to eq(GetStreamRuby::StreamError)

    end

  end

  describe 'APIError back-compat alias' do

    before do

      # Reset the once-warned flag so each test sees a fresh state.
      GetStreamRuby.instance_variable_set(:@apierror_alias_warned, false)
      GetStreamRuby.send(:remove_const, :APIError) if GetStreamRuby.const_defined?(:APIError, false)

    end

    it 'resolves to ApiError' do

      original_stderr = $stderr
      $stderr = StringIO.new
      begin
        expect(GetStreamRuby::APIError).to eq(GetStreamRuby::ApiError)
      ensure
        $stderr = original_stderr
      end

    end

    it 'emits a Kernel.warn deprecation on first access only' do

      messages = []
      allow(Kernel).to receive(:warn) { |msg| messages << msg }

      _first = GetStreamRuby::APIError
      _second = GetStreamRuby::APIError

      expect(messages.size).to eq(1)
      expect(messages.first).to include('APIError')
      expect(messages.first).to include('deprecated').or include('renamed')

    end

  end

  describe 'ApiError fields' do

    let(:err) do

      GetStreamRuby::ApiError.new(
        message: 'boom',
        status_code: 400,
        code: 4,
        exception_fields: { 'user_id' => 'required' },
        unrecoverable: true,
        raw_response_body: '{"code":4}',
        more_info: 'https://docs.example/4',
        details: ['x'],
      )

    end

    it 'exposes all eight fields plus the message' do

      expect(err.message).to eq('boom')
      expect(err.status_code).to eq(400)
      expect(err.code).to eq(4)
      expect(err.exception_fields).to eq('user_id' => 'required')
      expect(err.unrecoverable).to be(true)
      expect(err.raw_response_body).to eq('{"code":4}')
      expect(err.more_info).to eq('https://docs.example/4')
      expect(err.details).to eq(['x'])

    end

    it 'defaults exception_fields to {} and unrecoverable to false' do

      e = GetStreamRuby::ApiError.new(message: 'm', status_code: 500, code: 0)
      expect(e.exception_fields).to eq({})
      expect(e.unrecoverable).to be(false)
      expect(e.raw_response_body).to eq('')

    end

  end

  describe 'TaskError fields' do

    let(:err) do

      GetStreamRuby::TaskError.new(
        task_id: 't-1',
        error_type: 'panic',
        description: 'died',
        stack_trace: 'stack',
        version: '1.0',
      )

    end

    it 'exposes attributes and uses description as the message' do

      expect(err.task_id).to eq('t-1')
      expect(err.error_type).to eq('panic')
      expect(err.description).to eq('died')
      expect(err.message).to eq('died')
      expect(err.stack_trace).to eq('stack')
      expect(err.version).to eq('1.0')

    end

  end

  describe 'TransportError cause-chain preservation' do

    it 'sets Exception#cause when raised inside a Faraday rescue block' do

      err = begin
        begin
          raise Faraday::ConnectionFailed, 'reset'
        rescue Faraday::Error
          raise GetStreamRuby::TransportError.new('wrapped', error_type: 'connection_reset')
        end
      rescue GetStreamRuby::TransportError => e
        e
      end

      expect(err.cause).to be_a(Faraday::ConnectionFailed)
      expect(err.error_type).to eq('connection_reset')

    end

  end

end

RSpec.describe 'GetStreamRuby::Client error wrapping' do

  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:base_url) { 'https://chat.stream-io-api.test' }
  let(:client) do

    c = GetStreamRuby.manual(api_key: 'k', api_secret: 's', base_url: base_url)
    test_conn = Faraday.new(url: base_url) do |conn|

      conn.request :multipart
      conn.response :json, content_type: /\bjson$/
      conn.adapter :test, stubs

    end
    c.instance_variable_set(:@connection, test_conn)
    c

  end

  describe '4xx with an APIError envelope' do

    it 'raises ApiError populated from the response body' do

      body = {
        code: 4,
        message: 'invalid input',
        exception_fields: { 'user_id' => 'required' },
        more_info: 'https://getstream.io/docs',
        unrecoverable: true,
        StatusCode: 400,
        details: [1, 2],
        duration: '3ms',
      }
      stubs.post('/api/v2/test') { [400, { 'Content-Type' => 'application/json' }, body.to_json] }

      expect { client.post('/api/v2/test') }.to raise_error(GetStreamRuby::ApiError) do |err|

        expect(err.status_code).to eq(400)
        expect(err.code).to eq(4)
        expect(err.message).to eq('invalid input')
        expect(err.exception_fields).to eq('user_id' => 'required')
        expect(err.more_info).to eq('https://getstream.io/docs')
        expect(err.unrecoverable).to be(true)
        expect(err.details).to eq([1, 2])
        expect(err.raw_response_body).not_to be_empty

      end

    end

  end

  describe '429 rate-limit' do

    let(:body) { { code: 9, message: 'slow down', StatusCode: 429 }.to_json }

    it 'raises RateLimitError with Retry-After parsed as integer seconds' do

      stubs.post('/api/v2/rl') { [429, { 'Content-Type' => 'application/json', 'Retry-After' => '30' }, body] }

      expect { client.post('/api/v2/rl') }.to raise_error(GetStreamRuby::RateLimitError) do |err|

        expect(err.retry_after).to be_within(0.0001).of(30.0)
        expect(err.status_code).to eq(429)
        expect(err.code).to eq(9)

      end

    end

    it 'raises RateLimitError with Retry-After parsed as HTTP-date' do

      future = Time.now + 45
      headers = { 'Content-Type' => 'application/json', 'Retry-After' => future.httpdate }
      stubs.post('/api/v2/rl') { [429, headers, body] }

      expect { client.post('/api/v2/rl') }.to raise_error(GetStreamRuby::RateLimitError) do |err|

        expect(err.retry_after).to be > 0
        expect(err.retry_after).to be <= 46.0

      end

    end

    it 'clamps a past HTTP-date Retry-After to 0' do

      past = Time.now - 60
      headers = { 'Content-Type' => 'application/json', 'Retry-After' => past.httpdate }
      stubs.post('/api/v2/rl') { [429, headers, body] }

      expect { client.post('/api/v2/rl') }.to raise_error(GetStreamRuby::RateLimitError) do |err|

        expect(err.retry_after).to eq(0.0)

      end

    end

    it 'leaves retry_after nil when the header is absent' do

      stubs.post('/api/v2/rl') { [429, { 'Content-Type' => 'application/json' }, body] }

      expect { client.post('/api/v2/rl') }.to raise_error(GetStreamRuby::RateLimitError) do |err|

        expect(err.retry_after).to be_nil

      end

    end

    it 'is still rescuable as ApiError (inheritance check)' do

      stubs.post('/api/v2/rl') { [429, { 'Content-Type' => 'application/json' }, body] }
      expect { client.post('/api/v2/rl') }.to raise_error(GetStreamRuby::ApiError)

    end

  end

  describe 'unparseable response body' do

    it 'raises ApiError with code=0 and the canonical generic message' do

      stubs.post('/api/v2/x') { [500, { 'Content-Type' => 'text/plain' }, 'oops'] }

      expect { client.post('/api/v2/x') }.to raise_error(GetStreamRuby::ApiError) do |err|

        expect(err.status_code).to eq(500)
        expect(err.code).to eq(0)
        expect(err.message).to eq('failed to parse error response')
        expect(err.raw_response_body).to eq('oops')

      end

    end

  end

  describe 'transport-layer failures' do

    it 'wraps Faraday::ConnectionFailed as TransportError with cause preserved' do

      stubs.post('/api/v2/x') { raise Faraday::ConnectionFailed, 'reset' }

      expect { client.post('/api/v2/x') }.to raise_error(GetStreamRuby::TransportError) do |err|

        expect(err.error_type).to eq('connection_reset')
        expect(err.cause).to be_a(Faraday::Error)

      end

    end

    it 'classifies Faraday::TimeoutError as timeout' do

      stubs.post('/api/v2/x') { raise Faraday::TimeoutError, 'too slow' }

      expect { client.post('/api/v2/x') }.to raise_error(GetStreamRuby::TransportError) do |err|

        expect(err.error_type).to eq('timeout')

      end

    end

    it 'classifies Faraday::SSLError as tls_handshake_failed' do

      stubs.post('/api/v2/x') { raise Faraday::SSLError, 'bad cert' }

      expect { client.post('/api/v2/x') }.to raise_error(GetStreamRuby::TransportError) do |err|

        expect(err.error_type).to eq('tls_handshake_failed')

      end

    end

    it 'classifies a ConnectionFailed wrapping SocketError as dns_failure' do

      # Pass the underlying exception as the first arg so Faraday::Error
      # captures it as `wrapped_exception` (its constructor uses the second
      # positional arg as the response, not the wrapped exception).
      stubs.post('/api/v2/x') do

        raise Faraday::ConnectionFailed, SocketError.new('Name or service not known')

      end

      expect { client.post('/api/v2/x') }.to raise_error(GetStreamRuby::TransportError) do |err|

        expect(err.error_type).to eq('dns_failure')

      end

    end

  end

end

RSpec.describe 'GetStreamRuby::Client#wait_for_task' do

  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:base_url) { 'https://chat.stream-io-api.test' }
  let(:client) do

    c = GetStreamRuby.manual(api_key: 'k', api_secret: 's', base_url: base_url)
    test_conn = Faraday.new(url: base_url) do |conn|

      conn.request :multipart
      conn.response :json, content_type: /\bjson$/
      conn.adapter :test, stubs

    end
    c.instance_variable_set(:@connection, test_conn)
    c

  end

  before { allow(client).to receive(:sleep) }

  it 'returns the result payload when the task completes' do

    counter = 0
    stubs.get('/api/v2/tasks/abc') do

      counter += 1
      body = if counter < 2

               { status: 'pending', task_id: 'abc' }

             else

               { status: 'completed', task_id: 'abc', result: { 'ok' => true, 'count' => 3 } }

             end
      [200, { 'Content-Type' => 'application/json' }, body.to_json]

    end

    result = client.wait_for_task('abc', poll_interval: 0)
    expect(counter).to be >= 2
    expect(result.to_h).to eq('ok' => true, 'count' => 3)

  end

  it 'raises TaskError populated from the ErrorResult when the task fails' do

    stubs.get('/api/v2/tasks/abc') do

      body = {
        status: 'failed',
        task_id: 'abc',
        error: {
          type: 'panic',
          description: 'worker died',
          stacktrace: 'goroutine 1 [running]: ...',
          version: 'v1.2.3',
        },
      }
      [200, { 'Content-Type' => 'application/json' }, body.to_json]

    end

    expect { client.wait_for_task('abc', poll_interval: 0) }.to raise_error(GetStreamRuby::TaskError) do |err|

      expect(err.task_id).to eq('abc')
      expect(err.error_type).to eq('panic')
      expect(err.description).to eq('worker died')
      expect(err.message).to eq('worker died')
      expect(err.stack_trace).to eq('goroutine 1 [running]: ...')
      expect(err.version).to eq('v1.2.3')

    end

  end

  it 'raises TransportError(error_type: "timeout") when the deadline elapses' do

    stubs.get('/api/v2/tasks/abc') do

      [200, { 'Content-Type' => 'application/json' }, { status: 'pending', task_id: 'abc' }.to_json]

    end

    err = begin
      client.wait_for_task('abc', poll_interval: 0, timeout: 0)
      nil
    rescue GetStreamRuby::TransportError => e
      e
    end

    expect(err).to be_a(GetStreamRuby::TransportError)
    expect(err.error_type).to eq('timeout')

  end

end
