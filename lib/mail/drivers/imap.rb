# Copyright (C) 2012 by Alex Brandt <alunduil@alunduil.com>
#
# muaor is freely distributable under the terms of an MIT-style license.
# See COPYING or http://www.opensource.org/licenses/mit-license.php.

require 'net/imap'

module Mail
  module Drivers
    class IMAP
      def self.new(host, ssl)
        return Net::IMAP.new(host, ssl)
      end
    end
  end
end

