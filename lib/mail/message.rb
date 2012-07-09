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

