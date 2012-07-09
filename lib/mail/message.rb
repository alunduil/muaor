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
      @uid = @connection.fetch(msn, "UID").first.attr["UID"] unless @uid = kwargs.delete(:uid)
      @data = {}
      kwargs.each do |k,v|
        method, property = k.split('.').map { |i| i.downcase.to_sym }
        @data[method] ||= {}
        @data[method][property] = v.split(':', 2).last.strip
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
      @date[:headers].select { |k,v| headers.include? k }
    end

    def headers!(*headers)
      raise ArgumentError, "wrong number of arguments (0 for 1 or more)" if headers.empty?
      @data[:headers] ||= {}

      keys = Hash.new { |h, k| h[k] = "BODY[HEADER.FIELDS (#{k.to_s.upcase})]" }
      headers.each { |h| @data[:headers][h] = @connection.uid_fetch(@uid, keys[h]).first.attr[keys[h]].split(':', 2).last.strip }

      return @data[:headers][headers.first] if headers.length == 1
      @data[:headers].select { |k,v| headers.include? k }
    end
  end
end

