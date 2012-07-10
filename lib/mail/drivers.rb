# Copyright (C) 2012 by Alex Brandt <alunduil@alunduil.com>
#
# muaor is freely distributable under the terms of an MIT-style license.
# See COPYING or http://www.opensource.org/licenses/mit-license.php.

module Mail
  #
  # == Description
  #
  # This module provides the various drivers under a consistent interface
  # for MUAOR.
  #
  # == Objects
  # The objects provided by Mail::Drivers:
  # * Driver -> Factory for all drivers
  # * IMAP
  #
  # == Examples
  # === Using the Driver
  #
  #   require 'mail/drivers/driver'
  #
  #   driver = Mail::Drivers::Driver.new(protocol, host)
  #
  module Drivers
    require 'mail/drivers/driver'
  end
end

