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
  class Server # TODO Rename to server?
    def initialize(server, username, password, kwargs = {})
      kwargs[:method] = kwargs[:method].nil? && :login
      kwargs[:tls] = kwargs[:tls].nil? && true

      @server = server
      @username = username
      @password = password
      @method = kwargs[:method]
      @tls = kwargs[:tls]

      login

      # TODO Check for correctness ...
      ObjectSpace.define_finalizer(self, proc { @connection.logout } )
    end

    def initialize_copy(original)
      login
    end

    def login
      @connection = Net::IMAP.new(@server, :ssl => @tls)
      raise BadAuthMechanism, "Expected auth mechanism in (#{authentication_mechanisms}).  Got #{@method}." unless authentication_mechanisms.include? @method
      @connection.authenticate(@method.to_s.upcase, @username, @password)
    end
    private :login

    def capabilities
      @_capabilities ||= capabilities!
    end

    def capabilities!
      @_capabilities = @connection.capability.each { |c| c.downcase.sub(/\s/, "_").to_sym }
    end

    def authentication_mechanisms
      @_authentication_mechanisms ||= authentication_mechanisms!
    end

    def authentication_mechanisms!
      @_authentication_mechanisms = capabilities.select { |c| c.match(/^auth/i) }.each { |c| c.partition("=")[-1] }
    end

    def mailboxes(*globs) # TODO Caching of this method sim. capabilities?
      new_mailbox = lambda { |mb| Mailbox.new(mb.name, self) }

      @connection.list.each { |mb| yield new_mailbox(mb) } if globs.empty?
      globs.each do |g|
        if g[/[*%]/]
          @connection.list("", g).each { |mb| yield new_mailbox(mb) }
        else
          @connection.list(g).each { |mb| yield new_mailbox(mb) }
        end
      end
    end

    def create_mailbox!(name)
      @connection.create(name)
      mailboxes(name)
    end

    def delete_mailbox!(name)
      @connection.delete(name)
    end

    def disconnect # TODO Alias at all?
      @connection.disconnect
    end

    def disconnected?
      @connection.disconnected?
    end

    def connected?
      not disconnected?
    end

    class BadAuthMechanismError < Net::IMAP::Error; end
  end
end

