# frozen_string_literal: true

require 'json'
require 'time'

module GetStreamRuby

  # Translates HTTP responses and Faraday errors into SDK exceptions.
  module ErrorMapping

    module_function

    # Raises the appropriate `ApiError` / `RateLimitError` for a non-2xx
    # `Faraday::Response`.
    def raise_api_error(response)
      parsed_body = parse_error_body(response.body)
      raw_body = stringify_body(response.body)

      if parsed_body.is_a?(Hash)
        api_error = GetStream::Generated::Models::APIError.new(parsed_body)
        attrs = api_error_attrs(api_error, response.status, raw_body)

        if response.status == 429
          raise RateLimitError.new(
            retry_after: parse_retry_after(response_header(response, 'Retry-After')),
            **attrs,
          )
        end

        raise ApiError.new(**attrs)
      end

      raise ApiError.new(
        message: 'failed to parse error response',
        status_code: response.status,
        code: 0,
        exception_fields: {},
        unrecoverable: false,
        raw_response_body: raw_body,
        more_info: nil,
        details: nil,
      )
    end

    def api_error_attrs(model, status, raw_body)
      {
        message: model.message || "Request failed with status #{status}",
        status_code: status,
        code: model.code || 0,
        exception_fields: model.exception_fields || {},
        unrecoverable: model.unrecoverable.nil? ? false : model.unrecoverable,
        raw_response_body: raw_body,
        more_info: model.more_info,
        details: model.details,
      }
    end

    def parse_error_body(body)
      return body if body.is_a?(Hash)
      return nil unless body.is_a?(String) && !body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    def stringify_body(body)
      return '' if body.nil?
      return body if body.is_a?(String)

      body.to_json
    end

    def response_header(response, name)
      headers = response.headers
      return nil if headers.nil?

      # Faraday normalizes header names to lowercase, but tolerate either form.
      headers[name] || headers[name.downcase] || headers[name.to_s]
    end

    # Parse Retry-After header. Returns Float seconds. Returns nil when absent or
    # unparseable. Past HTTP-dates clamp to 0.
    def parse_retry_after(header)
      return nil if header.nil?

      value = header.to_s.strip
      return nil if value.empty?
      return value.to_f if value.match?(/\A\d+\z/)

      begin
        target = Time.httpdate(value)
        delta = target - Time.now
        delta.negative? ? 0.0 : delta.to_f
      rescue ArgumentError
        nil
      end
    end

    def classify_faraday_error(error)
      case error
      when Faraday::TimeoutError
        'timeout'
      when Faraday::SSLError
        'tls_handshake_failed'
      when Faraday::ConnectionFailed
        classify_connection_failure(error)
      else
        'unknown'
      end
    end

    def classify_connection_failure(error)
      wrapped = error.respond_to?(:wrapped_exception) ? error.wrapped_exception : nil
      case wrapped
      when SocketError
        'dns_failure'
      else
        'connection_reset'
      end
    end

    def build_task_error(task_id, error_payload)
      hash = if error_payload.respond_to?(:to_h)
               error_payload.to_h
             else
               error_payload || {}
             end
      TaskError.new(
        task_id: task_id,
        error_type: lookup(hash, :type) || '',
        description: lookup(hash, :description) || '',
        stack_trace: lookup(hash, :stacktrace),
        version: lookup(hash, :version),
      )
    end

    def lookup(hash, key)
      hash[key] || hash[key.to_s]
    end

  end

end
