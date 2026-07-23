# frozen_string_literal: true

module GetStreamRuby

  # Opt-in auto-retry policy. Disabled by default: the client performs exactly
  # one attempt and surfaces errors unchanged. When enabled, only GET/HEAD
  # requests failing with HTTP 429 or a transport error are retried.
  class RetryConfig

    attr_reader :max_attempts, :max_backoff

    def initialize(enabled: false, max_attempts: 3, max_backoff: 30.0)
      raise ArgumentError, 'max_attempts must be >= 1' if max_attempts < 1
      raise ArgumentError, 'max_backoff must be >= 0' if max_backoff.negative?

      @enabled = enabled
      @max_attempts = max_attempts
      @max_backoff = max_backoff.to_f
    end

    def enabled?
      @enabled
    end

  end

end
