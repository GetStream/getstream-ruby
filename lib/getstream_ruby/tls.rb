# frozen_string_literal: true

require 'openssl'

module GetStreamRuby

  # TLS knobs that Faraday / Net::HTTP do not expose per-connection.
  module Tls

    module_function

    # OpenSSL 3 treats a TCP FIN without TLS close_notify as an error. GCP
    # load balancers half-close idle keep-alive sockets that way, so
    # Net::HTTP's pre-reuse `eof?` probe raises `SSL_read: unexpected eof
    # while reading` instead of reporting a dead connection.
    #
    # `OP_IGNORE_UNEXPECTED_EOF` restores the OpenSSL 1.1.1 probe behavior.
    # Net::HTTP has no per-connection hook for SSLContext options, so this
    # is process-global. It only relaxes unclean-shutdown detection.
    def tolerate_unclean_shutdown!
      return unless defined?(OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF)

      OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |=
        OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
    end

  end

end
