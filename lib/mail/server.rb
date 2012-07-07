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
  class Server
    #
    # === Synopsis
    #
    #   Mail::Server.new(host, username, password, kwargs)
    #
    # === Arguments
    #
    # +host+::
    #   Hostname to connect to (String)
    # +username+::
    #   Username to connect with (String)
    # +password+::
    #   Password to connect with (String)
    # +kwargs+::
    #   Other optional arguments.  Meaningful values are:
    # * :method::
    #   The authentication method to sign in with.  Default :login
    # * :tls::
    #   Use TLS or SSL? Default true
    #
    # === Description
    #
    # Connect to the mail (IMAP) service at +host+ authenticating with
    # +username+ and +password+.
    #
    def initialize(host, username, password, kwargs = {})
      kwargs[:method] = :login if not kwargs.include? :method
      kwargs[:tls] = true if not kwargs.include? :tls

      @host = host
      @username = username
      @password = password
      @method = kwargs[:method]
      @tls = kwargs[:tls]

      login

      # TODO Check for correctness ...
      ObjectSpace.define_finalizer(self, proc { @connection.logout } )
      nil
    end

    def to_s
      "imap#{@tls ? "s" : ""}://#{@username}@#{@host}"
    end

    #
    # === Synopsis
    #   
    #   Mail::Server.dup
    #
    # === Description
    #
    # Duplicates the server object and ensures that a new connection comes with
    # the cloned instance.  Multi-connection situations can thus be created
    # with the following idea:
    #
    #   a = Mail::Server.new(host, username, password)
    #   b = a.dup
    #
    # All operations on a and b will be rectified by the server as part of the 
    # underlying mail implementation.  
    #
    def initialize_copy(original)
      login
    end

    #
    # Log into the mail server specified during instantiation.
    #
    def login
      @connection = Net::IMAP.new(@host, :ssl => @tls)
      raise BadAuthMechanismError, "Expected auth mechanism in (#{authentication_mechanisms}).  Got #{@method}." unless authentication_mechanisms.include? @method
      @connection.authenticate(@method.to_s.upcase, @username, @password)
    end
    private :login

    #
    # A list of symbols that correspond to the server's capabilities.  These
    # values will be cached in memory.  To bypass caching use
    # Mail::Server#capabilities!
    #
    def capabilities
      @_capabilities ||= capabilities!
    end

    #
    # See Mail::Server#capabilities
    #
    def capabilities!
      @_capabilities = @connection.capability.map { |c| c.downcase.sub(/\s/, "_").to_sym }
    end

    #
    # A list of symbols that correspond to the server's auth mechanisms.  These
    # values will be cached in memory.  To bypass caching use
    # Mail::Server#authentication_mechanisms!
    #
    def authentication_mechanisms
      @_authentication_mechanisms ||= authentication_mechanisms!
    end

    # 
    # See Mail::Server#authentication_mechanisms
    #
    def authentication_mechanisms!
      @_authentication_mechanisms = capabilities.select { |c| c.match(/^auth/i) }.map { |c| c.to_s.split("=")[-1].to_sym }
    end

    # 
    # === Synopsis
    #
    #   Mail::Server#mailboxes([globs, ...]) [ { |mailbox| ... } ]
    #
    # === Arguments
    # +globs+::
    #   List of globs (String) that specify mailboxes on the server.  These
    #   globs understand the '%' and '*' globs.  The '*' matches zero or more
    #   characters, including the server's mailbox delimiter and the '%'
    #   matches zero or more characters, _not_ including the server's mailbox
    #   delimiter.  Zero or more globs can be passed to filter out mailboxes
    #   of interest.
    #
    # === Description
    #
    # Return the matched mailboxes for the globs passed (if no globs are passed
    # this returns all mailboxes.  Can be passed a block to perform an action
    # on the selected mailboxes but if no block is given returns an array of 
    # mailboxes [Mail::Mailbox].
    #
    def mailboxes(*globs) # TODO Caching of this method sim. capabilities?
      return [].inject { |mbs, mb| mailboxes(*globs) { |imb| mbs << mb } } if not block_given?
      @connection.list("", "*").each { |mb| yield Mailbox.send(:new, mb.name, self) } if globs.empty?
      globs.each { |g| @connection.list("", g).each { |mb| yield Mailbox.send(:new, mb.name, self) } }
      nil
    end

    # 
    # === Synopsis
    #
    #   Mail::Server#create_mailbox(name)
    #
    # === Arguments
    # +name+::
    #   Name of the mailbox to be created (String)
    #
    # === Description
    #
    # Crates a new mailbox on the server with the given +name+.
    #
    def create_mailbox!(name)
      @connection.create(name)
      mailboxes(name) { |mb| return mb }
    end

    # 
    # === Synopsis
    #
    #   Mail::Server#delete_mailbox(name)
    #
    # === Arguments
    # +name+::
    #   Name of the mailbox to be deleted (String)
    #
    # === Description
    #
    # Deletes the mailbox with +name+ on the server.
    #
    def delete_mailbox!(name)
      @connection.delete(name)
      nil
    end

    #
    # Disconnect from the server.
    #
    def disconnect # TODO Alias at all?
      @connection.disconnect
    end

    #
    # Check if the Server is disconnected from the mail server.
    #
    def disconnected?
      @connection.disconnected?
    end

    #
    # Check if the Server is connected to the mail server.
    #
    def connected?
      not disconnected?
    end

    attr_reader :connection
    private :connection

  end

  #
  # Error raised when the authentication mechanism requested is not supported
  # by the remote mail server.
  #
  # For example, when connecting to a server without the :plain
  # authentication mechanism:
  #
  #   Mail::Account#authentication_mechanism.include? :plain #=> false
  #
  # We would raise this error to explain that the mechanism can't be used if
  # requested:
  #
  #   Mail::Account.new(host, username, password, :method => :plain)
  #
  # raises the exception:
  #
  #   Mail::Server::BadAuthMechanismError: Expected auth mechanism in ([:ntlm, :gssapi, :login]).  Got plain.
  #
  class BadAuthMechanismError < Net::IMAP::Error; end
end

