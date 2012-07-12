# Copyright (C) 2012 by Alex Brandt <alunduil@alunduil.com>
#
# muaor is freely distributable under the terms of an MIT-style license.
# See COPYING or http://www.opensource.org/licenses/mit-license.php.

module Mail
  class Server
    #
    # === Synopsis
    #
    #   Mail::Server.new(protocol, host, username, password, kwargs)
    #
    # === Arguments
    # +protocol+::
    #   Protocol to connect to server with (Symbol):
    # * :imap
    # * :exchange (not implemented)
    # * :pop (not implemented)
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
    def initialize(protocol, host, username, password, kwargs = {})
      kwargs[:method] = :plain if not kwargs.include? :method
      kwargs[:tls] = true if not kwargs.include? :tls

      @protocol = protocol
      @host = host
      @username = username
      @password = password # TOOD Remove me?
      @method = kwargs[:method]
      @tls = kwargs[:tls]

      login

      # TODO Check for correctness ...
      ObjectSpace.define_finalizer(self, proc { @connection.logout } )
      nil
    end

    def to_s # :nodoc:
      "#{@protocol.to_s}#{@tls ? "s" : ""}://#{@username}@#{@host}"
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
    #   a = Mail::Server.new(protocol, host, username, password)
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
      @connection = Drivers::Driver.new(@protocol, @host, :ssl => @tls)
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
      @capabilities ||= capabilities!
    end

    alias caps capabilities

    #
    # See Mail::Server#capabilities
    #
    def capabilities!
      @capabilities = @connection.capability.map { |c| c.downcase.sub(/\s/, "_").to_sym }
    end

    alias caps! capabilities!

    #
    # A list of symbols that correspond to the server's auth mechanisms.  These
    # values will be cached in memory.  To bypass caching use
    # Mail::Server#authentication_mechanisms!
    #
    def authentication_mechanisms
      @authentication_mechanisms ||= authentication_mechanisms!
    end

    alias auth_mechs authentication_mechanisms

    # 
    # See Mail::Server#authentication_mechanisms
    #
    def authentication_mechanisms!
      @authentication_mechanisms = capabilities!.select { |c| c.match(/^auth/i) }.map { |c| c.to_s.split("=").last.to_sym }
    end

    alias auth_mechs! authentication_mechanisms!

    # 
    # === Synopsis
    #
    #   Mail::Server#mailboxes([globs, ...])
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
    # this returns all mailboxes.  Returns an array of mailboxes 
    # [Mail::Mailbox].  All results are cached to bypass caching use
    # Mail::Server#mailboxes!.
    #
    # TODO Add an option to search only subscribed mailboxes.
    #
    def mailboxes(*globs)
      @mailboxes ||= {}

      return @mailboxes["*"] ||= mailboxes! if globs.empty?

      unknown_globs = globs.to_set - @mailboxes.keys.to_set
      mailboxes!(*unknown_globs) unless unknown_globs.empty?

      return @mailboxes[globs.first] if globs.length == 1
      @mailboxes.select { |k,v| globs.include? k }.map { |k,v| v }.flatten
    end

    #
    # See Mail::Mailbox#mailboxes
    #
    def mailboxes!(*globs)
      @mailboxes ||= {}

      return @mailboxes["*"] = @connection.list("", "*").map { |mb| Mailbox.send(:new, mb.name, self) } if globs.empty?

      globs.each { |g| @mailboxes[g] = @connection.list("", g).map { |mb| Mailbox.send(:new, mb.name, self) } }

      return @mailboxes[globs.first] if globs.length == 1
      @mailboxes.select { |k,v| globs.include? k }.map { |k,v| v }.flatten
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
      mailboxes(name).first
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
      true
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
  class BadAuthMechanismError < ArgumentError; end
end

