# frozen_string_literal: true

require 'spec_helper'
require 'socket'
require 'openssl'
require 'faraday'
require 'faraday/net_http_persistent'

# CHA-4943: GCP LBs half-close idle keep-alive TLS without close_notify.
# OpenSSL 3 turns that into SSL_read: unexpected eof while reading on the
# next request unless OP_IGNORE_UNEXPECTED_EOF is set.
RSpec.describe 'stale keep-alive TLS (CHA-4943)' do

  def self_signed_context
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.parse('/CN=localhost')
    cert.issuer = cert.subject
    cert.public_key = key.public_key
    cert.not_before = Time.now - 60
    cert.not_after = Time.now + 3600
    cert.sign(key, OpenSSL::Digest.new('SHA256'))

    ctx = OpenSSL::SSL::SSLContext.new
    ctx.cert = cert
    ctx.key = key
    ctx
  end

  def start_half_close_server
    tcp = TCPServer.new('127.0.0.1', 0)
    port = tcp.addr[1]
    server = OpenSSL::SSL::SSLServer.new(tcp, self_signed_context)
    server.start_immediately = false
    thread = Thread.new do

      loop do

        raw = server.accept
        Thread.new(raw) do |sock|

          sock.accept
          loop { break if sock.gets.to_s.strip.empty? }
          body = '{"ok":true}'
          sock.write(
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n" \
            "Content-Length: #{body.bytesize}\r\nConnection: keep-alive\r\n\r\n#{body}",
          )
          sock.to_io.shutdown(Socket::SHUT_WR)
          sleep 5
          sock.to_io.close
        rescue StandardError
          nil

        end

      end

    rescue StandardError
      nil

    end
    [tcp, thread, port]
  end

  def faraday_conn(port, max_retries: 0)
    Faraday.new(url: "https://127.0.0.1:#{port}", ssl: { verify: false }) do |conn|

      conn.adapter :net_http_persistent, pool_size: 5 do |http|

        http.idle_timeout = 25
        http.max_retries = max_retries if http.respond_to?(:max_retries=)

      end

    end
  end

  def request(conn, method)
    conn.send(method) do |req|

      req.url '/api/v2/x'
      req.body = '{}' if method == :post

    end
  end

  around do |example|

    skip 'OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF is not defined' unless
      defined?(OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF)

    original = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options]
    OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] =
      original & ~OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
    example.run
    OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] = original

  end

  it 'reconnects GET and POST after a half-close when unclean shutdown is tolerated' do

    tcp, thread, port = start_half_close_server
    GetStreamRuby::Tls.tolerate_unclean_shutdown!

    conn = faraday_conn(port)
    expect(request(conn, :get).status).to eq(200)
    expect(request(conn, :get).status).to eq(200)

    conn = faraday_conn(port)
    expect(request(conn, :post).status).to eq(200)
    expect(request(conn, :post).status).to eq(200)
  ensure
    tcp&.close
    thread&.kill

  end

  it 'raises SSLError on a half-closed POST without OP_IGNORE_UNEXPECTED_EOF' do

    tcp, thread, port = start_half_close_server
    conn = faraday_conn(port, max_retries: 0)

    expect(request(conn, :post).status).to eq(200)
    expect { request(conn, :post) }.to raise_error(Faraday::SSLError, /unexpected eof/)
  ensure
    tcp&.close
    thread&.kill

  end

end
