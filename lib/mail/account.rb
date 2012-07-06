# Copyright (C) 2012 by Alex Brandt <alunduil@alunduil.com>
#
# This program is free software; you can redistribute it and#or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA  02111-1307, USA.

require 'net/imap'

module Mail
  class Account
    def initialize(server, username, password, method = :login, tls = true):
      @server = server
      @username = username
      @password = password
      @method = method
      @tls = tls

      login
    end

    private_class_method :new

    def initialize_copy(original)
      login
    end

    def login
      @connection = Net::IMAP.new(@server)
      @connection.starttls if @tls
      @connection.authenticate(@method.to_s, @username, @password)
    end
    private :login

    def capabilities
      @connection.capability.each { |c| c.downcase.sub(/\s/, "_").to_sym }
    end

    def mailboxes(*globs)
      if globs.size > 0 then
        for glob in globs do
          if glob.index "*" or glob.index "%" then
            @connection.list("", glob).each { |mb| yield mb }
          else
            @connection.list(glob).each { |mb| yield mb }
          end
        end
      else
        @connection.list.each { |mb| yield mb }
      end
    end
  end
end

