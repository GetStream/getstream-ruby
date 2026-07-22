# frozen_string_literal: true

module GetStreamRuby

  # Structured-logging event emission mixed into Client (kept in its own file
  # to stay under Metrics/ClassLength; these methods rely on Client's
  # @configuration/monotonic_now same as if they lived on the class directly).
  module RequestLogging

    private

    # One-shot WARN at construction so a log_bodies: true deployment can't miss
    # that bodies (secrets key-redacted, but otherwise verbatim) are now being
    # written to its logs.
    def warn_log_bodies_enabled
      return unless @configuration.log_bodies && @configuration.logger

      @configuration.logger.warn do

        'log_bodies is enabled: request and response bodies will be logged ' \
          '(secrets are key-redacted, but treat log storage as sensitive).'

      end
    end

    def log_request_sent(method, path, query_params, body_json = nil)
      logger = @configuration.logger
      return unless logger

      query = LogRedaction.redact_query(query_params).map { |k, v| "#{k}=#{v}" }.join('&')
      line = +"http.request.sent http.request.method=#{method} url.path=#{path} url.query=#{query}"
      line << " http.request.body=#{LogRedaction.redact_json_body(body_json)}" if @configuration.log_bodies && body_json
      logger.debug { line }
    end

    def log_response_received(response, started)
      logger = @configuration.logger
      return unless logger

      raw_body = raw_response_body(response)
      line = +"http.response.received http.response.status_code=#{response.status} " \
              "http.response.body.size=#{raw_body.bytesize} duration_ms=#{elapsed_ms(started)}"
      line << " http.response.body=#{LogRedaction.redact_json_body(raw_body)}" if @configuration.log_bodies
      logger.debug { line }
    end

    def log_request_failed(method, path, error, started)
      logger = @configuration.logger
      return unless logger

      error_type = ErrorMapping.classify_faraday_error(error)
      message = LogRedaction.redact_message(error.message)
      logger.error do

        "http.request.failed http.request.method=#{method} url.path=#{path} " \
          "error.type=#{error_type} error.message=#{message} duration_ms=#{elapsed_ms(started)}"

      end
    end

    def elapsed_ms(started)
      ((monotonic_now - started) * 1000).round
    end

    # The `:json` response middleware parses env[:body] in place once its
    # content type matches, so the raw wire string only survives via
    # `preserve_raw:` (see Client#build_connection). Falls back to
    # `response.body` itself when it was never parsed (non-JSON content type,
    # or no body).
    def raw_response_body(response)
      raw = response.env[:raw_body]
      return raw unless raw.nil?

      response.body.to_s
    end

  end

end
