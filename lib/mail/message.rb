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
    def initialize(msn, mailbox, *kwargs)
      @mailbox = mailbox
      @connection = @mailbox.send(:connection)
      @lock = MailboxLock.instance[@connection]

      uid = kwargs.include? :uid && kwargs.delete(:uid) || @connection.fetch(msn, "UID").first.attr["UID"]
    end

    private_class_method :new

    def to_s
      "#{uid} # #{headers(:from)} -> #{headers(:to)} :: #{headers(:subject)}"
    end

    def uid
      @_uid ||= uid!
    end

    def uid=(value)
      @_uid = value
    end
    private :uid=

    def uid! # Just in case ...
      @_uid = @connection.uid_fetch(@_uid, "UID").first.attr["UID"]
    end

    def headers(header) # TODO Multiple headers at a time.
      @_headers ||= {}
      @_headers[header] ||= headers!(header)
    end

    def headers!(header)
      @_headers ||= {}
      key = "BODY[HEADER.FIELDS (#{property.to_s.upcase}]"
      @_headers[header] ||= @connection.uid_fetch(uid!, key).first.attr[key]
  end
end

