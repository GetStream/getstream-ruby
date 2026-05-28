# frozen_string_literal: true

module GetStreamRuby

  # Base error class for the SDK. Every SDK-raised exception is a subclass.
  class StreamError < StandardError; end

  # Back-compat alias. The prior base class was `Error`; keep it usable so
  # any existing `rescue GetStreamRuby::Error` clauses keep matching.
  Error = StreamError

  class ConfigurationError < StreamError; end

  # Raised on any HTTP 4xx/5xx response. Also raised when an HTTP response is
  # received but its body is not a parseable `APIError` envelope, with `code = 0`
  # and `message = "failed to parse error response"`.
  class ApiError < StreamError

    attr_reader :status_code, :code, :exception_fields, :unrecoverable,
                :raw_response_body, :more_info, :details

    def initialize(message:, status_code:, code:, exception_fields: nil,
                   unrecoverable: nil, raw_response_body: nil,
                   more_info: nil, details: nil)
      super(message)
      @status_code = status_code
      @code = code
      @exception_fields = exception_fields || {}
      @unrecoverable = unrecoverable.nil? ? false : unrecoverable
      @raw_response_body = raw_response_body || ''
      @more_info = more_info
      @details = details
    end

  end

  # Raised on HTTP 429. Adds parsed `Retry-After` as Float seconds, or nil when
  # the header is absent or unparseable. Per RFC 7231, both integer-seconds and
  # HTTP-date forms are supported. Past HTTP-dates clamp to 0.
  class RateLimitError < ApiError

    attr_reader :retry_after

    def initialize(retry_after: nil, **kwargs)
      super(**kwargs)
      @retry_after = retry_after
    end

  end

  # Allowed values for `TransportError#error_type`.
  TRANSPORT_ERROR_TYPES = %w[
    connection_reset
    timeout
    dns_failure
    tls_handshake_failed
    unknown
  ].freeze

  # Raised when no HTTP response is received: connection reset, timeout, TLS
  # handshake failure, DNS failure. Always raised inside the matching `rescue`
  # block so Ruby auto-sets `Exception#cause` to the underlying Faraday error.
  class TransportError < StreamError

    attr_reader :error_type

    def initialize(message = nil, error_type: 'unknown')
      super(message)
      @error_type = error_type
    end

  end

  # Raised by `Client#wait_for_task` when an async task finishes with
  # status="failed". Carries the populated `ErrorResult` fields.
  class TaskError < StreamError

    attr_reader :task_id, :error_type, :description, :stack_trace, :version

    def initialize(task_id:, error_type:, description:,
                   stack_trace: nil, version: nil)
      super(description)
      @task_id = task_id
      @error_type = error_type
      @description = description
      @stack_trace = stack_trace
      @version = version
    end

  end

  # Deprecated alias for ApiError. Will be removed in v9.0.
  # Implemented via `const_missing` so the first access emits a `Kernel.warn`
  # once-only and the constant is cached afterwards (no per-rescue noise).
  @apierror_alias_warned = false

  def self.const_missing(name)
    if name == :APIError
      unless @apierror_alias_warned
        Kernel.warn(
          '[DEPRECATION] GetStreamRuby::APIError is renamed to ' \
          'GetStreamRuby::ApiError. The old constant will be removed in v9.0.',
        )
        @apierror_alias_warned = true
      end
      const_set(:APIError, ApiError)
      ApiError
    else
      super
    end
  end

end
