# Copyright (C) 2012 by Alex Brandt <alunduil@alunduil.com>
#
# muaor is freely distributable under the terms of an MIT-style license.
# See COPYING or http://www.opensource.org/licenses/mit-license.php.

module Mail
  module Drivers
    class Driver
      #
      # === Synopsis
      #
      #   Driver.new(protocol, host, ssl)
      #
      # === Arguments
      # +protocol+::
      #   Selects the protocol driver
      # +host+::
      #   The host to connect to
      # +ssl+::
      #   Enables encryption in the driver if applicable
      #
      # === Description
      #
      # A factory for creating the driver necessary to communicate with the
      # requested protocol.
      #
      # ==== Protocols
      # * IMAP
      #
      def self.new(protocol, host, ssl)
        case protocol
        when :imap
          require 'mail/drivers/imap'
          return Mail::Drivers::IMAP.new(host, ssl)
        end
      end
    end
  end
end

