# Copyright (C) 2012 by Alex Brandt <alunduil@alunduil.com>
#
# muaor is freely distributable under the terms of an MIT-style license.
# See COPYING or http://www.opensource.org/licenses/mit-license.php.

require 'net/imap'
require 'singleton'
require 'aquarium'

module Mail
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
      @connection = @server.send(:connection)
      @lock = MailboxLock.instance[@connection]
      @name = name
    end

    private_class_method :new

    #
    # Name of the Mailbox.
    #
    attr_reader :name

    def to_s # :nodoc:
      "#{@account.to_s}/#{@name}"
    end

    #
    # Delete the Mailbox on the server.
    #
    def delete!
      @server.delete_mailbox(@name)
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
    #   Mail::Mailbox#append(message)
    #
    # === Arguments
    #
    # +message+::
    #   The message to add to the Mailbox (Mail::Message)
    #
    # === Description
    #
    # Inserts the passed Message into the Mailbox.
    #
    def append(message)
      @connection.append(@name, message.raw, message.flags.each { |f| f.to_s.capitalize.to_sym }, message.date)
      true
    end
    private :append

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
      message.send(:connection) == @connection ? append(message) : message.copy(self)
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
    #   Mail::Mailbox#messages([filters, ...])
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
    # Return the matched messages from the Mailbox as an Array.  The results 
    # are cached but the caching can be bypassed by using
    # Mail::Mailbox#messages!.
    #
    def messages(*filters)
      @messages ||= {}
      key = filters.join
      messages!(*filters) unless @messages.include? key
      @messages[key]
    end

    # 
    # See Mail::Mailbox#messages
    #
    def messages!(*filters)
      @messages ||= {}
      key = filters.join
      @messages[key] = [] # Clear cache ...

      if filters.empty? # Get the basics about all messages ...
        @connection.fetch(1..unlocked_count(:messages), [
                          "UID",
                          "BODY.PEEK[HEADER.FIELDS (SUBJECT)]",
                          "BODY.PEEK[HEADER.FIELDS (TO)]",
                          "BODY.PEEK[HEADER.FIELDS (FROM)]",
                          "FLAGS",
        ]).each do |f|
          @messages[key] << Message.send(:new, f.seqno, self,
                               :uid => f.attr["UID"],
                               "headers.subject" => f.attr["BODY[HEADER.FIELDS (SUBJECT)]"],
                               "headers.to" => f.attr["BODY[HEADER.FIELDS (TO)]"],
                               "headers.from" => f.attr["BODY[HEADER.FIELDS (FROM)]"],
                               "flags" => f.attr["FLAGS"],
                              )
        end
      end

      # TODO Add special filter translations here ...
      #@connection.search([]).each { |msn| msgs << Message.new(msn, self) } if filters.empty?

      @messages[key]
    end

    alias search messages

    #
    # The Mailbox's quota.
    #
    def quota
      return nil if @server.capabilities.select { |c| c.match(/^quota=/i) }.empty?
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
      true
    end

    #
    # Mark Mailbox as unsubscribed.
    #
    def unsubscribe
      @connection.unsubscribe(@name)
      true
    end

    #
    # Currently subscribed to the mailbox?
    #
    def subscribed?
      not unsubscribed?
    end

    #
    # Currently unsubscribed to the mailbox?
    #
    def unsubscribed?
      @connection.lsub("", @name).nil?
    end

    #
    # Check the Mailbox (a.k.a. Flush state to disk on server).
    #
    def check
      @connection.check
    end

    alias save check

    # TODO Add freeze to change select to examine.
    
    #
    # Get the current ACL of the Mailbox.
    #
    def acls
      return nil unless @server.capabilities.include? :acl
      @connection.getacl(@name) # TODO Check the return of this call.
    end

    def sort(sort_by, filter_by = :all)
      @connection.sort(sort_by, filter_by, "UTF-8").each { |msn| yield Message.new(msn, self) }
    end

    #
    # === Synopsis
    #
    #   Mail::Mailbox#count(property)
    #
    # === Arguments
    # +property+::
    #   Property to count (Symbol)
    #
    #   Can be one of the following: :messages, :recent, :unseen:
    #
    # * :messages - Count of all messages in Mailbox
    # * :recent - Count of recent messages in Mailbox
    # * :unseen - Count of unseen (unread) messages in Mailbox
    #
    # === Description
    #
    # Provides various counts of messages in the Mailbox in various states.
    #
    def count(property)
      unlocked_count(property)
    end

    around :calls_to => [:sort, :check, :save, :search, :messages, :expunge, :close, :count] do |jp, obj, *args|
      obj.send(:before)
      result = jp.proceed
      obj.send(:after)
      result
    end

    private

    attr_reader :connection

    def unlocked_count(property)
      key = property.to_s.upcase
      @connection.status(@name, [key])[key].to_int
    end

    def before
      @lock.lock
      @connection.select(@name)
    end

    def after
      @lock.unlock
    end

  end

  private

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
end

