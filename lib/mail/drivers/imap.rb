# Copyright (C) 2012 by Alex Brandt <alunduil@alunduil.com>
#
# muaor is freely distributable under the terms of an MIT-style license.
# See COPYING or http://www.opensource.org/licenses/mit-license.php.

require 'net/imap'

module Mail
  module Drivers
    class IMAP
      #
      # === Synopsis
      #
      #   Mail::Drivers::IMAP.new(host, ssl)
      #
      # === Arguments
      # +host+::
      #   Host to connect to (String)
      # +ssl+::
      #   Use security? (Bool)
      #
      # === Description
      #
      # Wrapper to Net::IMAP.new.  At least, until another driver necessitates
      # changing the upstream interface to be more generic.
      #
      def self.new(host, ssl)
        return Net::IMAP.new(host, ssl)
      end
    end
  end
end

# Hack stolen from http://www.semicomplete.com/blog/tags/imap to counteract the
# idiocracy which is exchange.
# TODO Move this to the exchange driver (or exchange IMAP hacks).
module Net
  class IMAP
    class ResponseParser
      def continue_req
        match(T_PLUS)
        #match(T_SPACE)
        return ContinuationRequest.new(resp_text, @str)
      end

      def response
        token = lookahead
        case token.symbol
        when T_PLUS
          result = continue_req
        when T_STAR
          result = response_untagged
        else
          result = response_tagged
        end
        shift_token if lookahead.symbol == T_SPACE
        match(T_CRLF)
        match(T_EOF)
        return result
      end
    end
  end
end

