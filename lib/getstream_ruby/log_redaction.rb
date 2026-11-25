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
    # Control characters (C0, DEL, C1) plus the Unicode line/paragraph
    # separators: anything a log sink or viewer may treat as a line break or
    # terminal escape.
    CONTROL_CHARS = /[[:cntrl:]  ]/.freeze

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

    # Makes a log line single-line and inert: every control character is
    # replaced by its escaped form (CR -> `\r`, LF -> `\n`, ESC -> `\e`, ...),
    # so a value echoed into a log event (path, query, error message, body)
    # can't forge extra log lines or inject terminal escape sequences.
    # Non-UTF-8 input (e.g. a binary response body) is scrubbed first so the
    # match itself can't raise.
    def sanitize(value)
      string = value.to_s
      string = string.dup.force_encoding(Encoding::UTF_8) unless string.encoding == Encoding::UTF_8
      string = string.scrub unless string.valid_encoding?
      string.gsub(CONTROL_CHARS) { |char| char.dump[1..-2] }
    end

  end

end
