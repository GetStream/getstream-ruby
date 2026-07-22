# frozen_string_literal: true

require 'json'

module GetStreamRuby

  # Redaction helpers for the SDK's structured log events. Shallow by design.
  module LogRedaction

    REDACTED = '<redacted>'
    QUERY_PARAMS = %w[api_key api_secret token].freeze
    BODY_KEYS = %w[api_secret token password].freeze
    # Matches `key=value` for the secret query params wherever they appear in a
    # free-form string (e.g. a transport error message that embeds the request
    # URL), value runs up to the next `&`, whitespace, or end of string.
    MESSAGE_SECRET_PATTERN = /\b(#{QUERY_PARAMS.join('|')})=[^&\s]*/i.freeze

    module_function

    def redact_query(params)
      return params if params.nil? || params.empty?

      params.to_h { |k, v| [k, QUERY_PARAMS.include?(k.to_s.downcase) ? REDACTED : v] }
    end

    def redact_json_body(body)
      return body if body.nil? || body.empty?

      data = JSON.parse(body)
      return body unless data.is_a?(Hash)

      changed = false
      BODY_KEYS.each do |key|

        if data.key?(key)
          data[key] = REDACTED
          changed = true
        end

      end
      changed ? JSON.generate(data) : body
    rescue JSON::ParserError
      body
    end

    # Redacts secret query-parameter values wherever they appear in a free
    # string (e.g. `error.message` from a transport exception, which may embed
    # the full request URL). Case-insensitive on the key; the value is
    # replaced regardless of its own case.
    def redact_message(string)
      return string if string.nil? || string.empty?

      string.gsub(MESSAGE_SECRET_PATTERN) { "#{Regexp.last_match(1)}=#{REDACTED}" }
    end

  end

end
