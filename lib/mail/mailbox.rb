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
require 'singleton'
require 'aquarium'

module Mail
  class MailboxLock
    include Singleton

    def initialize
      @mutexes = {}
    end

    #
    # === Synopsis
    #
    #   Mail::MailboxLock#locks(connection)
    #
    # === Arguments
    # +connection+::
    #   The connection that we're using is the key for the lock (Net::IMAP)
    #
    # === Description
    #
    # Get the particular mutex for the connection being used by the mailbox.
    #
    def locks(connection)
      @mutexes[connection] = Mutex.new unless @mutexes.has_key? connection
      @mutexes[connection]
    end

    alias [] locks
  end

  class Mailbox
    include Aquarium::DSL

    # 
    # === Synopsis
    #
    #   Mail::Mailbox.new(name, server)
    #
    # === Arguments
    #
    # +name+::
    #   Mailbox name for select in the upstream mail protocol (String)
    # +server+::
    #   Server this mailbox is associated with.
    #
    # === Description
    #
    # A private method as this should only be invoked from a Server object.
    # To get a mailbox object one should utilize Mail::Server#mailboxes or
    # Mail::Server#create_mailbox.
    #
    def initialize(name, server)
      @server = server
      @connection = server.send(:connection)
      @lock = MailboxLock.instance[@connection]
      @name = name
    end

    private :new

    attr_reader :name

    alias to_s name

    #
    # Delete the Mailbox on the server.
    #
    def delete! # TODO Drop the !?
      @server.delete_mailbox(@name)
    end

    #
    # === Synopsis
    #
    #   Mail::Mailbox#append(message)
    #
    # === Arguments
    #
    # +message+::
    #   Message to append to the Mailbox (Mail::Message)
    #
    # === Description
    #
    # Appends the passed message to the Mailbox. This can be used to create a
    # new message in the Mailbox or create a duplicate in the Mailbox.
    #
    def append(message)
      @connection.append(@name, message.raw, message.flags, Time.now)
    end

    #
    # Close the current Mailbox (Expunge and Deselect).
    #
    def close
      @connection.close()
    end

    #
    # === Synopsis
    #
    #   Mail::Mailbox#<<(message)
    #
    #   Mail::Mailbox << message
    #
    # === Arguments
    #
    # +message+::
    #   The message to add or duplicate into the Mailbox (Mail::Message)
    #
    # === Description
    #
    # Inserts the passed Message into the Mailbox.  This can be chained:
    #
    #   Mail::Mailbox << message1 << message2 << message3 ...
    #
    def <<(message)
      @message.new? ? append(message) : message.copy(@name)
      self
    end

    #
    # Expunge messages that are marked :deleted from the Mailbox.
    #
    def expunge
      @connection.expunge
    end

    #
    # === Synopsis
    #
    #   Mail::Mailbox#messages([filters, ...]) [ { |message| ... } ]
    #
    # === Arguments
    #
    # +filters+::
    #   Filters that select particular messages from the Mailbox.
    #
    #   Examples:
    #     
    # === Description
    #
    # Return the matched messages from the Mailbox and perform the block action
    # on the messages.  If no block is passed the list of messages is returned.
    #
    def messages(*filters)
      new_message = lambda { |msn| Message.new(msn, self) } # msn -> msg seq num

      return @connection.search.each { |msn| new_message(msn) } if filters.empty?

      # TODO Add special filter processing here ...
      @connection.search(filters).each { |msn| new_message(msn) }
    end

    alias search messages

    #
    # The Mailbox's quota.
    #
    def quota
      @connection.getquotaroot(@name) # TODO Check the return of this call.
    end

    #
    # Change the Mailbox's name.
    #
    def name=(name)
      @connection.rename(@name, name)
      @name = name
      # TODO Check for subscription change?
    end

    #
    # Mark Mailbox as subscribed.
    #
    def subscribe
      @connection.subscribe(@name)
    end

    #
    # Mark Mailbox as unsubscribed.
    #
    def unsubscribe
      @connection.unsubscribe(@name)
    end

    #
    # Check the Mailbox (a.k.a. Flush state to disk on server).
    #
    def check
      @connection.check
    end

    alias save check # TODO Good or not?

    # TODO Add freeze to change select to examine.
    
    #
    # Get the current ACL of the Mailbox.
    #
    def acls
      @connection.getacl(@name) # TODO Check the return of this call.
    end

    def sort(sort_by, filter_by = :all)
      @connection.sort(sort_by, filter_by, "UTF-8").each { |msn| yield Message.new(msn, self) }
    end

    def count(property)
      key = property.to_s.upcase
      @connection.status(@name, [key])[key].to_int
    end

    around :calls_to => [:sort, :check, :save, :search, :messages, :expunge, :close, :count] do |jp, obj, *args|
      @lock.lock
      @connection.select(@name)
      result = join_point.proceed
      @lock.unlock
      result
    end
  end
end

