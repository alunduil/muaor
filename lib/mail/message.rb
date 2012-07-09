# Copyright (C) 2012 by Alex Brandt <alunduil@alunduil.com>
#
# Expectr is freely distributable under the terms of an MIT-style license.
# See COPYING or http://www.opensource.org/licenses/mit-license.php.

require 'net/imap'

module Mail
  class Message
    def initialize(msn, mailbox, kwargs = {})
      @mailbox = mailbox
      @connection = @mailbox.send(:connection)
      @lock = MailboxLock.instance[@connection]

      if kwargs.include? :uid
        @uid = kwargs.delete(:uid)
      else
        @uid = @connection.fetch(msn, "UID").first.attr["UID"]
      end

      kwargs.each do |k,v|
        method, property = k.split('.').map { |i| i.downcase }
        instance_eval("@_#{method} ||= {}")
        instance_eval("@_#{method}[:#{property}] = '#{v}'.split(':', 2).last.strip")
      end
    end

    private_class_method :new

    def to_s
      "#{@uid} # #{headers(:from)} -> #{headers(:to)} :: #{headers(:subject)}"
    end

    def uid
      @uid ||= uid!
    end

    def uid! # Just in case ...
      @uid = @connection.uid_fetch(@uid, ["UID"]).first.attr["UID"]
    end

    def headers(*headers)
      raise ArgumentError, "wrong number of arguments (0 for 1 or more)" if headers.empty?
      @_headers ||= {}
      headers!(*headers) unless Set.new(headers).subset? Set.new(@_headers.keys)
      return @_headers[headers.first] if headers.length == 1
      @_headers.select { |k,v| headers.include? k }
    end

    def headers!(*headers)
      raise ArgumentError, "wrong number of arguments (0 for 1 or more)" if headers.empty?
      @_headers ||= {}
      keys = Hash.new { |h, k| h[k] = "BODY[HEADER.FIELDS (#{k.to_s.upcase})]" }
      headers.each do |h| 
        @_headers.merge!(h => @connection.uid_fetch(uid!, keys[h]).first.attr[keys[h]].split(':', 2).last.strip)
      end
      return @_headers[headers.first] if headers.length == 1
      @_headers.select { |k,v| headers.include? k }
    end
  end
end

