# frozen_string_literal: true

require 'faraday'
require 'faraday/gzip'
require 'faraday/retry'
require 'faraday/multipart'
require 'faraday/net_http_persistent'
require 'logger'
require 'json'
require 'jwt'
require_relative 'generated/base_model'
require_relative 'generated/common_client'
require_relative 'generated/feeds_client'
require_relative 'generated/moderation_client'
require_relative 'generated/chat_client'
require_relative 'generated/video_client'
require_relative 'extensions/moderation_extensions'
require_relative 'generated/feed'
require_relative 'generated/webhook'
require_relative 'generated/models/api_error'
require_relative 'stream_response'
require_relative 'error_mapping'

module GetStreamRuby

  class Client

    attr_reader :configuration

    def initialize(config = nil, api_key: nil, api_secret: nil, **options)
      @configuration = config || GetStreamRuby.configuration

      # Create new configuration with overrides if any parameters provided
      if api_key || api_secret || !options.empty?
        @configuration = Configuration.with_overrides(
          api_key: api_key,
          api_secret: api_secret,
          **options,
        )
      end

      @configuration.validate!
      @connection = build_connection
      @configuration.log_pool_config_to(@configuration.logger)
    end

    def feed_resource
      @feed_resource ||= Resources::Feed.new(self)
    end

    # Generated API clients

    # @return [GetStream::Generated::CommonClient] The common API client
    def common
      @common ||= GetStream::Generated::CommonClient.new(self)
    end

    # @return [GetStream::Generated::FeedsClient] The feeds API client
    def feeds
      @feeds ||= GetStream::Generated::FeedsClient.new(self)
    end

    # @return [GetStream::Generated::ModerationClient] The moderation API client
    def moderation
      @moderation ||= GetStream::Generated::ModerationClient.new(self)
    end

    # @return [GetStream::Generated::ChatClient] The chat API client
    def chat
      @chat ||= GetStream::Generated::ChatClient.new(self)
    end

    # @return [GetStream::Generated::VideoClient] The video API client
    def video
      @video ||= GetStream::Generated::VideoClient.new(self)
    end

    # Create an individual feed instance
    # @param feed_group_id [String] The feed group ID
    # @param feed_id [String] The feed ID
    # @return [GetStream::Generated::Feed] A feed instance
    def feed(feed_group_id, feed_id)
      GetStream::Generated::Feed.new(self, feed_group_id, feed_id)
    end

    # Verify a webhook signature using this client's API secret (CHA-2961).
    #
    # Convenience wrapper around StreamChat::Webhook.verify_signature that
    # supplies the secret automatically. The module-level method is still
    # available for callers that need to verify with an arbitrary secret.
    #
    # @param body [String] The raw request body (already-decompressed)
    # @param signature [String] The signature from the X-Signature header
    # @return [Boolean] true if the signature is valid, false otherwise
    def verify_signature(body, signature)
      StreamChat::Webhook.verify_signature(body, signature, @configuration.api_secret)
    end

    # Verify and parse a webhook payload in one call, using this client's API
    # secret (CHA-2961).
    #
    # Handles gzip-compressed bodies transparently. Raises
    # StreamChat::Webhook::InvalidWebhookError on signature mismatch or parse
    # failures; distinguish failure modes via the message substring.
    #
    # @param body [String] raw request body (possibly gzip-compressed)
    # @param signature [String] X-Signature header value
    # @return [Object] the typed event class instance or
    #         StreamChat::Webhook::UnknownEvent
    # @raise [StreamChat::Webhook::InvalidWebhookError]
    def verify_and_parse_webhook(body, signature)
      StreamChat::Webhook.verify_and_parse_webhook(body, signature, @configuration.api_secret)
    end

    # Decode + parse a Stream-delivered SQS message body.
    #
    # Convenience wrapper around StreamChat::Webhook.parse_sqs. No signature is
    # required; SQS deliveries are authenticated via AWS IAM.
    def parse_sqs(message_body)
      StreamChat::Webhook.parse_sqs(message_body)
    end

    # Decode + parse a Stream-delivered SNS notification body.
    #
    # Accepts either the raw SNS HTTP envelope JSON or the pre-extracted Message
    # string. Convenience wrapper around StreamChat::Webhook.parse_sns. No signature
    # is required; SNS deliveries are authenticated via AWS IAM.
    def parse_sns(notification_body)
      StreamChat::Webhook.parse_sns(notification_body)
    end

    # @param path [String] The API path
    # @param body [Hash] The request body
    # @return [GetStreamRuby::StreamResponse] The API response
    def post(path, body = {})
      request(:post, path, body)
    end

    # Polls the task-status endpoint until the task reaches a terminal state.
    #
    # Behaviour:
    #   - status="completed": returns the task `result` payload.
    #   - status="failed":    raises `TaskError` populated from the task's
    #                         `ErrorResult` (`type`, `description`, `stacktrace`,
    #                         `version`).
    #   - timeout elapsed:    raises `TransportError` with `error_type:
    #                         "timeout"`.
    #
    # @param task_id [String]
    # @param poll_interval [Numeric] seconds between polls (default 1)
    # @param timeout [Numeric] max seconds to wait (default 60)
    # @return [Object] the task `result` payload on success
    # @raise [TaskError] when the task reports `status="failed"`
    # @raise [TransportError] when the timeout elapses (`error_type="timeout"`)
    def wait_for_task(task_id, poll_interval: 1, timeout: 60)
      start_time = monotonic_now

      loop do

        response = common.get_task(task_id)
        status = response.status

        case status
        when 'completed'
          return response.result
        when 'failed'
          raise ErrorMapping.build_task_error(task_id, response.error)
        end

        if monotonic_now - start_time >= timeout
          raise TransportError.new(
            "wait_for_task timed out after #{timeout}s for task_id=#{task_id}",
            error_type: 'timeout',
          )
        end

        sleep(poll_interval)

      end
    end

    def make_request(method, path, query_params: nil, body: nil, request_timeout: nil)
      # Handle query parameters
      if query_params && !query_params.empty?
        query_string = query_params.map { |k, v| "#{k}=#{v}" }.join('&')
        path = "#{path}?#{query_string}"
      end

      # Make the request
      request(method, path, body, request_timeout: request_timeout)
    end

    private

    def request(method, path, data = {}, request_timeout: nil)
      # Add API key to query parameters
      query_params = { api_key: @configuration.api_key }

      # Check if this is a file upload request that needs multipart
      return make_multipart_request(method, path, query_params, data) if multipart_request?(data)

      response = @connection.send(method) do |req|

        req.url path, query_params
        req.headers['Authorization'] = generate_auth_header
        req.headers['Content-Type'] = 'application/json'
        req.headers['stream-auth-type'] = 'jwt'
        req.headers['X-Stream-Client'] = user_agent
        req.body = data.to_json
        req.options.timeout = request_timeout if request_timeout

      end

      handle_response(response)
    rescue Faraday::Error => e
      raise TransportError.new("Request failed: #{e.message}", error_type: ErrorMapping.classify_faraday_error(e))
    end

    def build_connection
      # Escape hatch #1: user supplied a fully-built Faraday::Connection.
      # Use it as-is; none of the 5 knobs apply.
      return @configuration.http_client if @configuration.http_client

      Faraday.new(url: @configuration.base_url) do |conn|

        conn.request :multipart
        conn.request :retry, {
          max: 3,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2,
        }
        conn.response :json, content_type: /\bjson$/
        # :gzip must come after :json (Faraday runs response middleware in reverse).
        conn.request :gzip
        configure_adapter(conn)

        conn.options.timeout = @configuration.request_timeout
        conn.options.open_timeout = @configuration.connect_timeout

      end
    end

    def configure_adapter(connection)
      # Escape hatch #2: custom adapter symbol. Use it with the user's
      # adapter_options; do NOT apply pool_size/idle_timeout (those are
      # net_http_persistent-specific).
      if @configuration.faraday_adapter
        adapter = @configuration.faraday_adapter
        adapter_options = @configuration.faraday_adapter_options || {}
        # Header-based keep-alive only on the custom-adapter path.
        # net_http_persistent (default) keeps connections alive natively without any HTTP header.
        connection.headers['Connection'] = 'keep-alive' if @configuration.connection_keep_alive
        connection.adapter(adapter, **adapter_options)
        return
      end

      # Default: net_http_persistent with the 5-knob config.
      # Never set Connection: close; net_http_persistent keeps connections alive natively.
      idle = @configuration.idle_timeout
      connection.adapter :net_http_persistent, pool_size: @configuration.max_conns_per_host do |http|

        http.idle_timeout = idle

      end
    rescue Faraday::Error, ArgumentError => e
      # A fallback silently disables pooling, so always WARN (never swallow).
      @configuration.warn_pool_fallback(Faraday.default_adapter, e)
      connection.adapter Faraday.default_adapter
      # Record the adapter actually built so the INFO log reports it accurately.
      @configuration.effective_adapter = Faraday.default_adapter.to_s
    end

    # Backdate the JWT `iat` claim by this many seconds.
    #
    # JWT timestamps are whole-second (RFC 7519 NumericDate), so `Time.now.to_i`
    # truncates to the second. The server applies minimal forward leeway on
    # `iat`, so stamping `iat = now` lets a small fraction of requests be
    # rejected ("token used before issue at (iat)") whenever the caller's clock
    # is even marginally ahead of the server and the truncation lands on a
    # second boundary. Backdating absorbs that sub-second skew.
    AUTH_IAT_LEEWAY_SECONDS = 5

    def generate_auth_header
      JWT.encode(
        {
          iat: Time.now.to_i - AUTH_IAT_LEEWAY_SECONDS,
          server: true,
        },
        @configuration.api_secret,
        'HS256',
      )
    end

    def user_agent
      "getstream-ruby-#{GetStreamRuby::VERSION}"
    end

    def handle_response(response)
      return StreamResponse.new(response.body) if (200..299).cover?(response.status)

      ErrorMapping.raise_api_error(response)
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def multipart_request?(data)
      return false if data.nil? || data == {}

      # Check if data is a FileUploadRequest or ImageUploadRequest
      data.is_a?(GetStream::Generated::Models::FileUploadRequest) ||
        data.is_a?(GetStream::Generated::Models::ImageUploadRequest)
    end

    def make_multipart_request(method, path, query_params, data)
      # Build multipart form data
      payload = {}

      # Handle file field
      raise ArgumentError, 'file name must be provided' if data.file.nil? || data.file.empty?

      file_path = data.file
      raise ArgumentError, "file not found: #{file_path}" unless File.exist?(file_path)

      # Determine content type
      content_type = detect_content_type(file_path)

      # Add file as multipart (FilePart handles file opening/closing)
      payload[:file] = Faraday::Multipart::FilePart.new(
        file_path,
        content_type,
        File.basename(file_path),
      )

      # Add user field if present (as JSON string)
      if data.user
        user_json = data.user.to_json
        payload[:user] = user_json
      end

      # Add upload_sizes field for ImageUploadRequest (as JSON string)
      if data.is_a?(GetStream::Generated::Models::ImageUploadRequest) && data.upload_sizes
        upload_sizes_json = data.upload_sizes.to_json
        payload[:upload_sizes] = upload_sizes_json
      end

      response = @connection.send(method) do |req|

        req.url path, query_params
        req.headers['Authorization'] = generate_auth_header
        req.headers['stream-auth-type'] = 'jwt'
        req.headers['X-Stream-Client'] = user_agent
        req.body = payload

      end

      handle_response(response)
    rescue Faraday::Error => e
      raise TransportError.new("Request failed: #{e.message}", error_type: ErrorMapping.classify_faraday_error(e))
    end

    def detect_content_type(file_path)
      ext = File.extname(file_path).downcase
      case ext
      when '.png'
        'image/png'
      when '.jpg', '.jpeg'
        'image/jpeg'
      when '.gif'
        'image/gif'
      when '.pdf'
        'application/pdf'
      when '.txt'
        'text/plain'
      when '.json'
        'application/json'
      else
        'application/octet-stream'
      end
    end

  end

end
