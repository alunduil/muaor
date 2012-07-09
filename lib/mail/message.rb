# Copyright (C) 2012 by Alex Brandt <alunduil@alunduil.com>
#
# muaor is freely distributable under the terms of an MIT-style license.
# See COPYING or http://www.opensource.org/licenses/mit-license.php.

require 'net/imap'
require 'aquarium'

module Mail
  class Message
    include Aquarium::DSL

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

    attr_reader :uid

    def to_s # :nodoc:
      "#{@uid} # #{headers(:from)} -> #{headers(:to)} :: #{headers(:subject)}"
    end

    def headers(*headers)
      raise ArgumentError, "wrong number of arguments (0 for 1 or more)" if headers.empty?
      @data[:headers] ||= {}

      unknown_headers = headers.to_set - @data[:headers].keys.to_set
      headers!(*unknown_headers) unless unknown_headers.empty?

      return @data[:headers][headers.first] if headers.length == 1
      @data[:headers].select { |k,v| headers.include? k }
    end

    def headers!(*headers)
      raise ArgumentError, "wrong number of arguments (0 for 1 or more)" if headers.empty?
      @data[:headers] ||= {}

      keys = Hash.new { |h, k| h[k] = "BODY.PEEK[HEADER.FIELDS (#{k.to_s.upcase})]" }
      headers.each { |h| @data[:headers][h] = @connection.uid_fetch(@uid, keys[h]).first.attr[keys[h].sub(/\.PEEK/, "")].split(':', 2).last.strip }

      return @data[:headers][headers.first] if headers.length == 1
      @data[:headers].select { |k,v| headers.include? k }
    end

    def message_id
      @data[:envelope] ||= {}
      @data[:envelope][:message_id] ||= message_id!
    end

    def message_id!
      @data[:envelope] ||= {}
      @data[:envelope][:message_id] = @connection.uid_fetch(@uid, ["ENVELOPE"]).first.attr["ENVELOPE"].message_id
    end

    def flags
      @data[:flags] ||= flags!
    end

    def flags!
      @data[:flags] = @connection.uid_fetch(@uid, ["FLAGS"]).first.attr["FLAGS"].map { |f| f.to_s.downcase.to_sym }.to_set
    end

    def flags=(flags)
      raise ArgumentError, "argument must be of type Set" unless flags.class == Set
      @connection.uid_store(@uid, "FLAGS", flags.map { |f| f.to_s.capitalize.to_sym })
      @data[:flags] = flags
    end

    def raw
      @data[:raw] ||= raw!
    end

    def raw!
      @data[:raw] = @connection.uid_fetch(@uid, ["BODY.PEEK[]"]).first.attr["BODY[]"]
    end

    def size
      @data[:size] ||= size!
    end

    def size!
      @data[:size] = @connection.uid_fetch(@uid, ["RFC822.SIZE"]).first.attr["RFC822.SIZE"]
    end

    def text
      @data[:text] ||= text!
    end

    def text!
      @data[:text] = @connection.uid_fetch(@uid, ["BODY.PEEK[TEXT]"]).first.attr["BODY[TEXT]"]
    end

    def copy(mailbox)
      @connection.uid_copy(@uid, mailbox.name)
    end

    def move(mailbox)
      copy(mailbox)
      delete!
    end

    def delete!
      flags |= [:deleted]
    end

    def read!
      flags |= [:seen]
    end
  end
end

