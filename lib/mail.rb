# Copyright (C) 2012 by Alex Brandt <alunduil@alunduil.com>
#
# muaor is freely distributable under the terms of an MIT-style license.
# See COPYING or http://www.opensource.org/licenses/mit-license.php.

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
# The objects provided by MUAOR are the following:
# * Server
# * Mailbox
# * Message
#
# These resource looking objects map directly to the upstream mail
# implementation commands and allow interesting interactions like those shown
# in the examples below.
#
# == Examples
# === Logging In
#
#   require 'mail'
#
#   mail = Server.new(:imap, "example.com", "username", "password", :MECHANISM)
#
# === Listing Mailboxes
#
#   require 'mail'
#
#   mail = Server.new(:imap, "example.com", "username", "password", :MECHANISM)
#   mail.mailboxes.each { |mb| p mb }
#
# === Listing Particular Mailboxes
#
#   require 'mail'
#
#   mail = Server.new(:imap, "example.com", "username", "password", :MECHANISM)
#   mail.mailboxes("Example Folder*", "INBOX").each { |mb| p mb }
#
# === Listing Message Properties for Messages in a Mailbox
#
#   require 'mail'
#   require 'date'
#
#   mail = Server.new(:imap, "example.com", "username", "password", :MECHANISM)
#   mail.mailboxes("INBOX").each do |mb|
#     mb.messages.each { |m| p m.headers(:subject) }
#   end
#
module Mail
  require 'mail/drivers'
  require 'mail/server'
  require 'mail/mailbox'
  require 'mail/message'
end

# Hack stolen from http://www.semicomplete.com/blog/tags/imap to counteract the
# idiocracy which is exchange.
# TODO Move this to the exchange driver (or exchange IMAP hacks).
module Net
  class IMAP
    class ResponseParser
      def continue_req
        match(T_PLUS)
        #match(T_SPACE)
        return ContinuationRequest.new(resp_text, @str)
      end

      def response
        token = lookahead
        case token.symbol
        when T_PLUS
          result = continue_req
        when T_STAR
          result = response_untagged
        else
          result = response_tagged
        end
        shift_token if lookahead.symbol == T_SPACE
        match(T_CRLF)
        match(T_EOF)
        return result
      end
    end
  end
end

