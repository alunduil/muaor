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
  # TODO Find a better method of determining the account for the mailbox ...
  class Mailbox
    def self.create(name, account)
      account.send(connection).create(name)
    end

    def self.delete(name, account)
      account.send(connection).delete(name)
    end

    @@account_lock = Mutex.new

    def initialize(name, account)
      @account = account
      @connection = account.send(connection)
      @name = name
    end

    def delete!
      Mailbox.delete(@name, @account)
    end

    def append(message)
      @connection.append(@name, message.raw, message.flags, Time.now)
    end

    def close
      @connection.close()
    end

    def <<(message)
      @message.new? ? append(message) : message.copy(@name)
    end

    def expunge
      @connection.expunge
    end

    def messages(*filters)
      new_message = lambda { |msn| Message.new(msn, self) } # msn -> msg seq num

      return @connection.search.each { |msn| new_message(msn) } if filters.empty?

      # TODO Add special filter processing here ...
      @connection.search(filters).each { |msn| new_message(msn) }
    end

    def quota
      @connection.getquotaroot(@name) # TODO Check the return of this call.
    end

    def name=(name)
      @connection.rename(@name, name)
      @name = name
      # TODO Check for subscription change?
    end

    alias search messages

    def subscribe
      @connection.subscribe(@name)
    end

    def unsubscribe
      @connection.unsubscribe(@name)
    end

    def check
      @connection.check
    end

    alias save check # TODO Good or not?

    # TODO Add freeze to change select to examine.
    
    def acls
      @connection.getacl(@name) # TODO Check the return of this call.
    end

    def sort!(sort_by, filter_by = :all)
      new_message = lambda { |msn| Message.new(msn, self) }
      @connection.sort(sort_by, filter_by, "UTF-8").each { |msn| new_message(msn) }
    end

    def count(property)
    end

    @select_methods = [
      :append, :close
    ] # TODO is the right context for this list?

    before(*@select_methods) do 
      @@account_lock.lock
      @connection.select(@name) 
    end # TODO Verify

    after(*@select_methods) do
      @@account_lock.unlock
    end # TODO Verify

    private

    def self.before(*methods)
      methods.each do |method|
        define_method(method) do |*args, &block|
          yield
          m.bind(self).(*args, &block)
        end
      end
    end

    def self.after(*methods)
      methods.each do |method|
        define_method(method) do |*args, &block|
          m.bind(self).(*args, &block)
          yield
        end
      end
    end
  end
end

