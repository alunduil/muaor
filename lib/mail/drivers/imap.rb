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

