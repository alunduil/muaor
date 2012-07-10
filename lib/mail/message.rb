# Copyright (C) 2012 by Alex Brandt <alunduil@alunduil.com>
#
# muaor is freely distributable under the terms of an MIT-style license.
# See COPYING or http://www.opensource.org/licenses/mit-license.php.

require 'net/imap'
require 'aquarium'

module Mail
  class Message
    include Aquarium::DSL

    #
    # === Synopsis
    #
    #   Mail::Message.new(msn, mailbox[, kwargs])
    #
    # === Arguments
    #
    # +msn+::
    #   Message Sequence Number -> relative reference to the message on the
    #   server (Integer)
    # +mailbox+::
    #   The mailbox this message currently belong to (Mail::Mailbox)
    # +kwargs+::
    #   Other options to bypass individual lookups by the Message:
    # * header.<HEADER> Value for the particular header on the Message.
    # * flags Set of flags to start the Message with.
    # * raw -> skipped
    # * size -> skipped
    # * text -> skipped
    #
    # === Description
    #
    # A private method as this should only be invoked from a Mailbox object.
    # To get a Message object one should utilize Mail::Mailbox#messages or
    # Mail::Mailbox#search.
    #
    def initialize(msn, mailbox, kwargs = {})
      @mailbox = mailbox
      @connection = @mailbox.send(:connection)
      @lock = MailboxLock.instance[@connection]
      @uid = @connection.fetch(msn, "UID").first.attr["UID"] unless @uid = kwargs.delete(:uid)

      @data = {}

      kwargs.each do |k,v|
        method, property = k.split('.').map { |i| i.downcase.to_sym }
        case method
        when :flags
          @data[:flags] = property.nil? ? Set.new : property.to_set 
        when :raw, :size, :text
          continue
        else
          @data[method] ||= {}
          @data[method][property] = v.split(':', 2).last.strip
        end
      end
    end

    private_class_method :new

    #
    # The UID of the Message
    #
    attr_reader :uid

    def to_s # :nodoc:
      "#{@uid} # #{headers(:from)} -> #{headers(:to)} :: #{headers(:subject)}"
    end

    #
    # === Synopsis
    #
    #   Mail::Message#headers(header, [header, ...])
    #
    # === Arguments
    # +headers+::
    #   List of headers to extract (Array[Symbol]) (e.g. :subject, :to, :from, etc)
    #
    # === Description
    #
    # List of headers on the message.  This method provides random access to
    # the Message's headers.  For the complete headers see Mail::Message#envelope.
    # To bypass caching for this method utilize Mail::Message#headers!
    #
    def headers(*headers)
      raise ArgumentError, "wrong number of arguments (0 for 1 or more)" if headers.empty?
      @data[:headers] ||= {}

      unknown_headers = headers.to_set - @data[:headers].keys.to_set
      headers!(*unknown_headers) unless unknown_headers.empty?

      return @data[:headers][headers.first] if headers.length == 1
      @data[:headers].select { |k,v| headers.include? k }
    end

    #
    # See Mail::Message#headers!
    #
    def headers!(*headers)
      raise ArgumentError, "wrong number of arguments (0 for 1 or more)" if headers.empty?
      @data[:headers] ||= {}

      keys = Hash.new { |h, k| h[k] = "BODY.PEEK[HEADER.FIELDS (#{k.to_s.upcase})]" }
      headers.each { |h| @data[:headers][h] = @connection.uid_fetch(@uid, keys[h]).first.attr[keys[h].sub(/\.PEEK/, "")].split(':', 2).last.strip }

      return @data[:headers][headers.first] if headers.length == 1
      @data[:headers].select { |k,v| headers.include? k }
    end

    #
    # Message ID of the Message
    #
    def message_id
      @data[:message_id] ||= message_id!
    end

    #
    # See Mail::Message#message_id
    #
    def message_id!
      @data[:message_id] = @connection.uid_fetch(@uid, ["ENVELOPE"]).first.attr["ENVELOPE"].message_id
    end

    #
    # Message's Envelope (All Headers)
    #
    def envelope
      @data[:envelope] ||= envelope!
    end

    #
    # See Mail::Message#envelope
    #
    def envelope!
      @data[:envelope] = @connection.uid_fetch(@uid, ["ENVELOPE"]).first.attr["ENVELOPE"] # TODO Check return value.
    end

    #
    # Message's Flags (i.e. :seen, :deleted, etc)
    #
    def flags
      @data[:flags] ||= flags!
    end

    #
    # See Mail::Message#flags
    #
    def flags!
      @data[:flags] = @connection.uid_fetch(@uid, ["FLAGS"]).first.attr["FLAGS"].map { |f| f.to_s.downcase.to_sym }.to_set
    end

    #
    # Set the flags on the Message
    #
    def flags=(flags)
      raise ArgumentError, "argument must be of type Set" unless flags.class == Set
      @connection.uid_store(@uid, "FLAGS", flags.map { |f| f.to_s.capitalize.to_sym })
      @data[:flags] = flags
    end

    #
    # Message's raw format.
    #
    def raw
      @data[:raw] ||= raw!
    end

    #
    # See Mail::Message#raw
    #
    def raw!
      @data[:raw] = @connection.uid_fetch(@uid, ["BODY.PEEK[]"]).first.attr["BODY[]"]
    end

    #
    # Size of the Message
    #
    def size
      @data[:size] ||= size!
    end

    #
    # See Mail::Message#size
    #
    def size!
      @data[:size] = @connection.uid_fetch(@uid, ["RFC822.SIZE"]).first.attr["RFC822.SIZE"]
    end

    #
    # Text portion of the Message
    #
    def text
      @data[:text] ||= text!
    end

    #
    # See Mail::Message#text
    def text!
      @data[:text] = @connection.uid_fetch(@uid, ["BODY.PEEK[TEXT]"]).first.attr["BODY[TEXT]"]
    end

    #
    # === Synopsis
    #
    #   Mail::Message#copy(mailbox)
    #
    # === Arguments
    # +mailbox+::
    #   Mailbox to copy this Message into (Mail::Mailbox)
    #
    # === Description
    #
    # Copies the Message to the passed Mailbox.
    #
    def copy(mailbox)
      @connection.uid_copy(@uid, mailbox.name)
    end

    #
    # === Synopsis
    #
    #   Mail::Message#move(mailbox)
    #
    # === Arguments
    # +mailboxes+::
    #   Mailbox to move this Message into (Mail::Mailbox)
    #
    # === Description
    #
    # Copies the Message to the passed Mailbox and then deletes the Message
    # from this Mailbox.
    #
    def move(mailbox)
      copy(mailbox)
      delete!
    end

    #
    # Delete this message.
    #
    def delete!
      self.flags = flags! | Set[:deleted]
    end

    #
    # Mark the Message as seen.
    #
    def read!
      self.flags = flags! | Set[:seen]
    end

    alias seen! read!

    #
    # Mark the Message as unread.
    def unread!
      self.flags -= Set[:seen]
    end

    alias unseen! unread!
  end
end

