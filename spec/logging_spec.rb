# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe 'structured logging' do

  def build(stubs, logger: nil, log_bodies: false)
    conn = Faraday.new { |b| b.adapter :test, stubs }
    options = { base_url: 'http://localhost', http_client: conn }
    options[:logger] = logger if logger
    options[:log_bodies] = log_bodies if log_bodies
    GetStreamRuby::Client.new(api_key: 'key', api_secret: 'sekret', **options)
  end

  def recorder
    io = StringIO.new
    logger = Logger.new(io)
    logger.level = Logger::DEBUG
    [logger, io]
  end

  it 'emits client.initialized once with the schema' do

    logger, io = recorder
    build(Faraday::Adapter::Test::Stubs.new, logger: logger)
    lines = io.string.lines.select { |l| l.include?('client.initialized') }
    expect(lines.size).to eq(1)
    expect(lines.first).to include('stream.sdk.name=getstream-ruby').and include('stream.client.max_conns_per_host=')

  end

  it 'emits sent and received on success' do

    stubs = Faraday::Adapter::Test::Stubs.new { |s| s.get(%r{/x}) { [200, { 'Content-Type' => 'application/json' }, '{"ok":true}'] } }
    logger, io = recorder
    build(stubs, logger: logger).make_request(:get, '/x')
    expect(io.string).to include('http.request.sent')
    expect(io.string).to include('http.response.received')
    expect(io.string).to include('http.response.status_code=200')

  end

  it 'routes 5xx through received, not failed' do

    stubs = Faraday::Adapter::Test::Stubs.new { |s| s.get(%r{/x}) { [500, {}, '{"code":1,"message":"boom"}'] } }
    logger, io = recorder
    client = build(stubs, logger: logger)
    expect { client.make_request(:get, '/x') }.to raise_error(GetStreamRuby::ApiError)
    expect(io.string).to include('http.response.status_code=500')
    expect(io.string).not_to include('http.request.failed')

  end

  it 'emits failed on transport error' do

    stubs = Faraday::Adapter::Test::Stubs.new { |s| s.get(%r{/x}) { raise Faraday::TimeoutError } }
    logger, io = recorder
    client = build(stubs, logger: logger)
    expect { client.make_request(:get, '/x') }.to raise_error(GetStreamRuby::TransportError)
    expect(io.string).to include('http.request.failed').and include('error.type=timeout')

  end

  it 'produces zero output without a logger' do

    stubs = Faraday::Adapter::Test::Stubs.new { |s| s.get(%r{/x}) { [200, {}, '{}'] } }
    expect { build(stubs).make_request(:get, '/x') }.not_to output.to_stdout

  end

  it 'redacts api_key in url.query' do

    stubs = Faraday::Adapter::Test::Stubs.new { |s| s.get(%r{/x}) { [200, {}, '{}'] } }
    logger, io = recorder
    build(stubs, logger: logger).make_request(:get, '/x')
    expect(io.string).not_to include('api_key=key')
    expect(io.string).to include('api_key=<redacted>')

  end

  it 'log_bodies opt-in adds redacted bodies and warns once' do

    stubs = Faraday::Adapter::Test::Stubs.new { |s| s.get(%r{/x}) { [200, { 'Content-Type' => 'application/json' }, '{"token":"supersecretvalue","keep":"v"}'] } }
    logger, io = recorder
    build(stubs, logger: logger, log_bodies: true).make_request(:get, '/x')
    expect(io.string.scan('bodies will be logged').size).to eq(1)
    expect(io.string).to include('http.response.body=')
    expect(io.string).not_to include('supersecretvalue')

  end

  it 'redaction helpers' do

    expect(GetStreamRuby::LogRedaction.redact_query({ api_key: 'k', x: 1 })).to eq({ api_key: '<redacted>', x: 1 })
    out = GetStreamRuby::LogRedaction.redact_json_body('{"api_secret":"s","password":"p","keep":"v"}')
    expect(out).not_to include('"s"')
    expect(out).to include('"keep":"v"')
    expect(GetStreamRuby::LogRedaction.redact_json_body('not json')).to eq('not json')

  end

  # PROACTIVE SECRET-LEAK GUARD: a Faraday transport error's #message may embed
  # the full request URL (with api_key/api_secret/token query values) verbatim.
  # error.message must be scrubbed before it reaches the logger.
  it 'redacts secrets embedded in the transport error message' do

    stubs = Faraday::Adapter::Test::Stubs.new do |s|

      s.get(%r{/x}) { raise Faraday::ConnectionFailed, 'execution expired for http://x/api/v2/app?api_key=SUPERSECRETKEY&user_id=123' }

    end
    logger, io = recorder
    client = build(stubs, logger: logger)
    expect { client.make_request(:get, '/x') }.to raise_error(GetStreamRuby::TransportError)
    failed_line = io.string.lines.find { |l| l.include?('http.request.failed') }
    expect(failed_line).to include('api_key=<redacted>')
    expect(failed_line).not_to include('SUPERSECRETKEY')

  end

  it 'LogRedaction.redact_message redacts secret query values in a free string' do

    msg = 'GET failed for http://x/api/v2/app?api_key=SUPERSECRETKEY&user_id=123'
    out = GetStreamRuby::LogRedaction.redact_message(msg)
    expect(out).to include('api_key=<redacted>')
    expect(out).not_to include('SUPERSECRETKEY')

  end

  # SEC-2535: caller query params used to be baked into url.path, bypassing
  # redact_query; they must now land in url.query and be redacted there.
  it 'redacts secret caller query params and keeps them out of url.path' do

    stubs = Faraday::Adapter::Test::Stubs.new { |s| s.get(%r{/x}) { [200, {}, '{}'] } }
    logger, io = recorder
    build(stubs, logger: logger).make_request(:get, '/x', query_params: { token: 'CALLERTOKEN', user_id: 'u1' })
    sent = io.string.lines.find { |l| l.include?('http.request.sent') }
    expect(sent).to include('url.path=/x url.query=')
    expect(sent).to include('token=<redacted>').and include('user_id=u1').and include('api_key=<redacted>')
    expect(io.string).not_to include('CALLERTOKEN')

  end

  it 'redacts secrets in a caller-built path' do

    stubs = Faraday::Adapter::Test::Stubs.new { |s| s.post(%r{/x}) { [200, {}, '{}'] } }
    logger, io = recorder
    build(stubs, logger: logger).post('/x?token=PATHTOKEN')
    expect(io.string).to include('url.path=/x?token=<redacted>')
    expect(io.string).not_to include('PATHTOKEN')

  end

  it 'never logs the Authorization header or the JWT' do

    stubs = Faraday::Adapter::Test::Stubs.new { |s| s.get(%r{/x}) { [200, {}, '{}'] } }
    logger, io = recorder
    build(stubs, logger: logger, log_bodies: true).make_request(:get, '/x')
    expect(io.string).not_to match(/authorization/i)
    expect(io.string).not_to include('eyJ')
    expect(io.string).not_to include('sekret')

  end

  # SEC-2535: CR/LF (and other control characters) in any logged value must
  # not be able to forge extra log lines.
  it 'escapes CR/LF in path, query, bodies and error messages' do

    forged = "\r\nI, [2026-01-01] INFO -- : forged"
    stubs = Faraday::Adapter::Test::Stubs.new do |s|

      s.post(%r{/ok}) { [200, { 'Content-Type' => 'text/plain' }, "body#{forged}"] }
      s.get(%r{/boom}) { raise Faraday::ConnectionFailed, "refused#{forged}" }

    end
    logger, io = recorder
    client = build(stubs, logger: logger, log_bodies: true)
    client.make_request(:post, '/ok', query_params: { user_id: "u1#{forged}" }, body: { text: "hi#{forged}" })
    expect { client.make_request(:get, '/boom') }.to raise_error(GetStreamRuby::TransportError)
    # Generated clients interpolate path params unencoded; the URI parser
    # rejects CR/LF, but only after http.request.sent was already logged.
    expect { client.make_request(:get, "/ok/c1#{forged}") }.to raise_error(URI::InvalidURIError)

    expect(io.string.lines.grep(/forged/).size).to eq(io.string.lines.grep(/forged/).uniq.size)
    expect(io.string.lines).to all(satisfy { |l| !l.start_with?('I, [2026-01-01]') })
    expect(io.string).to include('/ok/c1\\r\\nI, [2026-01-01]')
    expect(io.string).to include('user_id=u1\\r\\nI')
    expect(io.string).to include('http.response.body=body\\r\\nI')
    expect(io.string).to include('error.message=refused\\r\\nI')

  end

  it 'sanitize helper' do

    sanitize = GetStreamRuby::LogRedaction.method(:sanitize)
    expect(sanitize.call("a\r\nb\tc\e[31md\u2028e\u0085f")).to eq('a\\r\\nb\\tc\\e[31md\\u2028e\\u0085f')
    expect(sanitize.call("\xFF\n".b)).to eq("\uFFFD\\n")
    expect(sanitize.call(nil)).to eq('')
    expect(sanitize.call('plain ünïcode')).to eq('plain ünïcode')

  end

end
