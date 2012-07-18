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
    # Size of slices to send to upstream mail servers.
    #
    SLICE_SIZE = 3000

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
      @lock = MailboxLock.instance.locks(@connection)
      @name = name
    end

    private_class_method :new

    #
    # Name of the Mailbox.
    #
    attr_reader :name

    def to_s # :nodoc:
      "#{@server.to_s}/#{@name}"
    end

    #
    # Delete the Mailbox on the server.
    #
    def delete!
      @server.delete_mailbox!(@name)
    end

    #
    # Close the Mailbox (Expunge and Deselect).
    #
    def close
      @connection.close()
    end

    #
    # Select the Mailbox
    #
    def select
      @connection.select(@name)
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
      message.send(:connection) == @connection ? append(message) : message.copy(self)
      self
    end

    #
    # Expunge messages that are marked :deleted from the Mailbox.
    #
    def expunge
      @connection.expunge
      true
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
    #   * +:count+ => N # Number of messages to return
    #   * +:offset+ => N # First message to grab
    #   * +:new+ => true # Find only new messages. Defaults to nil; nil disables new selection
    #
    #   The following should not be used with the preceeding as the results are
    #   not logical.  They search the messages specified and do not return the
    #   number of messages as implied.
    #
    #   * "SELECTOR.OPERATION" => VALUE:
    #     +SELECTOR+:: 
    #       Identifier for a message section (e.g. headers.date, body, etc)
    #     +OPERATION+::
    #       The operation to compare based on:
    #       * \> Norm for Numbers but After for Dates and Superset for Set
    #       * \< Norm for Numbers but Before for Dates and Subset for Set
    #       * \= Norm for Numbers and Dates but Containment for Strings (a.k.a. "".match(/.\*String.\*/)
    #       * \~ Norm for Regexes but acts as = otherwise
    #       * Combinations work as expected:
    #         * \<\> Not equal
    #         * \>\= Greater than or equal
    #         * etc.
    #     +VALUE+::
    #       An appropriate value for the requested field and operation
    #
    #   Examples:
    #   * "headers.date.<" => Date # Find messages before this date
    #   * "body.~" => Regexp # Find messages whose body matches Regexp
    #   * "to.<" => Number # Find messages with less than Number of Recipients in To: TODO
    #     
    # === Description
    #
    # Return the matched messages from the Mailbox as an Array.  The results 
    # are cached per filterbut the caching can be bypassed by using
    # Mail::Mailbox#messages!.
    #
    def messages(filters = {})
      @messages ||= {}
      key = filters.to_a.join
      messages!(filters) unless @messages.include? key
      @messages[key]
    end

    alias search messages

    # 
    # See Mail::Mailbox#messages
    #
    def messages!(filters = {})
      @messages ||= {}
      key = filters.to_a.join
      @messages[key] = [] # Clear cache ...

      count = filters.delete(:count) || unlocked_count(:messages)
      offset = filters.delete(:offset) || 1
      
      return [] if count < 1

      if filters.empty? # Get the basics about all messages ...
        (offset..count).each_slice(SLICE_SIZE) do |s|
          @connection.fetch(s, [
                                             "UID",
                                             "BODY.PEEK[HEADER.FIELDS (SUBJECT)]",
                                             "BODY.PEEK[HEADER.FIELDS (TO)]",
                                             "BODY.PEEK[HEADER.FIELDS (FROM)]",
                                             "FLAGS"
          ]).each do |f|
            @messages[key] ||= []
            after
            @messages[key] << Message.send(:new, f.seqno, self,
                         :uid => f.attr["UID"],
                         "headers.subject" => f.attr["BODY[HEADER.FIELDS (SUBJECT)]"],
                         "headers.to" => f.attr["BODY[HEADER.FIELDS (TO)]"],
                         "headers.from" => f.attr["BODY[HEADER.FIELDS (FROM)]"],
                         "flags" => f.attr["FLAGS"]
            )
            before
          end
        end
        return @messages[key]
      end

      $stderr.puts "filters.has_key? :new => #{filters.has_key? :new}" if $DEBUG
      $stderr.puts "filters[:new] => #{filters[:new]}" if $DEBUG

      filters[:new] = filters.has_key? :new ? filters[:new] : nil

      second_pass = {}
      
      query = [ "#{offset}:#{count}" ]
      filters.each do |k,v|
        $stderr.puts "Adding: #{k} -> #{v}" if $DEBUG
        case k
        when :new # Allow for other symbol parameters.
          unless filters[v].nil?
            query << "NOT" unless v
            query << "NEW"
          end
        else
          selector, operator = k.rsplit('.',2)
          case
          when selector.start_with?("header")
            header = selector.rsplit('.', 2).last
            case header
            when "date"
              date = v.strftime("%d-%b-%Y")
              case operator
              when "<"
                query << "BEFORE" << date
              when ">"
                query << "SINCE" << date << "NOT" << "ON" << date
              when "<>"
                query << "NOT" << "ON" << date
              when "<="
                query << "BEFORE" << date << "ON" << date
              when ">="
                query << "SINCE" << date
              when "="
                query << "ON" << date
              else
                raise FilterParseError, "Operator, #{operator}, not defined for #{k}"
              end
            when "subject", "to", "from", "cc"
              case operator
              when "~"
                second_pass[k] = v
                strings = parse_regex(v)
                strings[:on].each { |s| query << header.upcase << s }
                strings[:off].each { |s| query << "NOT" << header.upcase << s }
              when "="
                query << header.upcase << v
              when "<>"
                query << "NOT" << header.upcase << v
              when "<"
                second_pass[k] = v unless header == "subject"
              when ">"
                second_pass[k] = v unless header == "subject"
              else
                raise FilterParseError, "Operator, #{operator}, not defined for #{k}"
              end
            end
          when selector.start_with?("body")
            case operator
            when "~"
              second_pass[k] = v
              strings = parse_regex(v)
              strings[:on].each { |s| query << selector.upcase << s }
              strings[:off].each { |s| query << "NOT" << selector.upcase << s }
            when "="
              query << selector.upcase << v
            when "<>"
              query << "NOT" << selector.upcase << v
            else
              raise FilterParseError, "Operator, #{operator}, not defined for #{k}"
            end
          when selector.start_with?("flag")
            second_pass[k] = v
          end
        end
      end

      $stderr.puts query.join(" ") if $DEBUG

      unless filters.empty?
        fetch_set = @connection.search(query)
        $stderr.puts "Fetching: #{fetch_set}" if $DEBUG
        return @messages[key] = [] if fetch_set.empty?

        fetch_set.each_slice(SLICE_SIZE) do |s|
          $stderr.puts "  Fetching: #{s}" if $DEBUG
          fetched = @connection.fetch(s, [
                                      "UID",
                                      "BODY.PEEK[HEADER.FIELDS (SUBJECT)]",
                                      "BODY.PEEK[HEADER.FIELDS (TO)]",
                                      "BODY.PEEK[HEADER.FIELDS (FROM)]",
                                      "FLAGS"
          ])
          $stderr.puts "  Fetched #{fetched}" if $DEBUG
          next unless fetched # TODO WTF?
          fetched.each do |f|
            @messages[key] ||= []
            after
            @messages[key] << Message.send(:new, f.seqno, self,
                         :uid => f.attr["UID"],
                         "headers.subject" => f.attr["BODY[HEADER.FIELDS (SUBJECT)]"],
                         "headers.to" => f.attr["BODY[HEADER.FIELDS (TO)]"],
                         "headers.from" => f.attr["BODY[HEADER.FIELDS (FROM)]"],
                         "flags" => f.attr["FLAGS"]
            )
            before
          end
        end
      end

      @messages[key].select do |m|
        true # TODO Second Pass ...
      end
    end

    alias search! messages!

    #
    # === Synopsis
    #
    #   Mail::Mailbox#batch(:action => Enumarable(Messages)[, ...])
    #
    # === Arguments
    # +actions+::
    #   Hash of action requested (i.e. :delete, :move, :copy) to enumerable
    #   containing Messages to apply the action.
    #
    # * +:delete+ -> Deletes the specified messages from this Mailbox
    # * +:copy+ -> Copies the specified messages into this Mailbox
    # * +:move+ -> Moves the specified messages into this Mailbox
    # * +:read+ -> Mark all specified messages read
    #
    #   The values of the hashes are Enumerables of Messages but the following
    #   values are also accepted for the specified special cases:
    #
    # * +:all+ -> Acts on all messages
    #
    # === Description
    #
    # Allows for batch operations on messages (using the upstream protocols capabilities).
    #
    def batch(actions = {})
      actions.each do |k,v|
        set = []

        if v == :all
          (1..unlocked_count(:messages)).each_slice(SLICE_SIZE) do |s|
            @connection.fetch(s, [
                              "UID",
                              "BODY.PEEK[HEADER.FIELDS (SUBJECT)]",
                              "BODY.PEEK[HEADER.FIELDS (TO)]",
                              "BODY.PEEK[HEADER.FIELDS (FROM)]",
                              "FLAGS"
            ]).each do |f|
              after
              set << Message.send(:new, f.seqno, self,
                                  :uid => f.attr["UID"],
                                  "headers.subject" => f.attr["BODY[HEADER.FIELDS (SUBJECT)]"],
                                  "headers.to" => f.attr["BODY[HEADER.FIELDS (TO)]"],
                                  "headers.from" => f.attr["BODY[HEADER.FIELDS (FROM)]"],
                                  "flags" => f.attr["FLAGS"]
                                 )
              before
            end
          end
        else
          set = v
        end

        return if set.empty?

        set.each_slice(SLICE_SIZE) do |s|
          # TODO Check the effects when :all is passed to copy or move ... Idempotent or duplicating?
          case k
          when :delete
            s.each do |m|
              @connection.uid_store(m.uid, "+FLAGS", [:Deleted])
            end
          when :read
            s.each do |m|
              @connection.uid_store(m.uid, "+FLAGS", [:Seen])
            end
          when :copy
            Set.new(s).classify { |m| m.mailbox }.each do |b,s|
              b.select
              s.each do |m|
                @connection.uid_copy(m.uid, @name)
              end
            end
          when :move
            Set.new(s).classify { |m| m.mailbox }.each do |b,s|
              next if b.name == @name
              b.select
              s.each do |m|
                @connection.uid_copy(m.uid, @name)
                @connection.uid_store(m.uid, "+FLAGS", [:Deleted])
              end
            end
          end
        end
      end
      true
    end

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

    around :calls_to => [:sort, :check, :save, :search!, :messages!, :expunge, :close, :append, :count, :batch] do |jp, obj, *args|
      obj.send(:before)
      result = jp.proceed
      obj.send(:after)
      result
    end

    private

    attr_reader :connection
    
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

    def unlocked_count(property)
      key = property.to_s.upcase
      @connection.status(@name, [key])[key].to_int
    end

    def before
      @lock.lock
      select
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
    #   The connection that we're using is the key for the lock (Mail::Drivers::Driver)
    #
    # === Description
    #
    # Get the particular mutex for the connection being used by the mailbox.
    #
    def locks(connection)
      @mutexes[connection] ||= Mutex.new 
    end
  end

end

class String
  def rsplit(pattern = $;, limit = 0)
    reverse.split(pattern, limit).map { |e| e.reverse }.reverse
  end
end

