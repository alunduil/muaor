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
      def initialize(host, ssl)
        @server = Net::IMAP.new(host, ssl)
        @exchange = false
      end

      #
      # === Synopsis
      #   
      #   Mail::Drivers::IMAP#authenticate(auth_type, *args)
      #
      # === Arguments
      # +auth_type+::
      #   The authentication mechanism.
      # +args+::
      #   Other arguments (i.e. username, password, etc).
      #
      # === Description
      #
      # Calls the upstream authenticator and determines if we're working with 
      # an exchange server or not.
      #
      def authenticate(auth_type, *args)
        begin
          @server.authenticate(auth_type, *args)
        rescue Net::IMAP::ResponseParseError => e
          raise unless e.message[/unexpected token CRLF \(expected SPACE\)/]
          @exchange = true
        end
      end

      #
      # Call the upstream module's method.
      #
      def method_missing(key, *args, &block)
        # TODO Add monkey patching to this location instead.
        @server.send(key, *args, &block)
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
        #match(T_SPACE) if lookahead.symbol == T_SPACE
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
        match(T_SPACE) if lookahead.symbol == T_SPACE
        match(T_CRLF)
        match(T_EOF)
        return result
      end
    end
  end
end

