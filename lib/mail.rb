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

# == Description
# MUAOR is a high level set of interactive objects for a network accessible
# mail services (i.e. IMAP, POP, Exchange, etc).  Currently, only IMAP is
# available but future versions will be able to support other protocols.
#
# Mail extends the capabilities of internal libraries (i.e. Net::IMAP) and does
# not look to replace them for low level interaction.  What MUAOR tries to
# accomplish is the resource view of a MUA.  This can be extended into an IMAP
# proxy, an over-the-network procmail replacement, a full blown MUA with a
# custom interface, or it can be used as is as an irb MUA.
#
# == Objects
# The objects provider by MUAOR are the following:
#   * Account
#   * Mailbox
#   * Message
#
# These resource looking objects map directly to the upstream mail
# implementation commands and allow interesting interactions like those shown
# in the examples below.
#
# == Examples
# === Logging In
#
#   require 'mail'
#   require 'mail/protocols/imap'
#
#   mail = Account.new("example.com", "username", "password", :MECHANISM)
#
# === Listing Mailboxes
#
#   require 'mail'
#   require 'mail/protocols/imap'
#
#   mail = Account.new("example.com", "username", "password", :MECHANISM)
#   mail.mailboxes { |mb| p mb }
#
# === Listing Particular Mailboxes
#
#   require 'mail'
#   require 'mail/protocols/imap'
#
#   mail = Account.new("example.com", "username", "password", :MECHANISM)
#   mail.mailboxes "Example Folder*" "Inbox" { |mb| p mb }
#
# === Listing Message Properties for Particular Messages
#
#   require 'date'
#
#   require 'mail'
#   require 'mail/protocols/imap'
#
#   mail = Account.new("example.com", "username", "password", :MECHANISM)
#   mail.mailboxes "INBOX" do |mb|
#     mb.messages "header.date.>" => Date.today - 1 { |m| p m.headers.subject }
#   end
#
module Mail
  require 'mail/account'
  #require 'mail/mailbox' TODO Add this back in after testing Account
  #require 'mail/message' TODO Add this back in after testing Account
end

