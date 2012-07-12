#!/bin/env ruby

require 'mail'
require 'optparse'
require 'pp'

opts = { :protocol => :imap }
OptionParser.new do |o|
  o.on('-u', "--username USER", String, "Username to login with") { |u| opts[:username] = u }
  o.on("-p", "--password PASS", String, "Password to login with") { |p| opts[:password] = p }
  o.on("-H", "--hostname HOST", String, "Hostname to login to") { |h| opts[:hostname] = h }
  o.on("--protocol PROTO", String, "Protocol to connect with") { |p| opts[:protocol] = p.to_sym }
  o.on_tail("-h", "--help", "Show this message") { puts o; exit }
  o.parse!(ARGV)
end

puts "Options found:"
pp opts

s = Mail::Server.new(opts[:protocol], opts[:hostname], opts[:username], opts[:password])

s.mailboxes.each do |b|
  deletes = b.messages("headers.to.=" => "ssl")
  puts "Delete the following:"
  deletes.each { |d| puts d }
  #b.batch(:delete, deletes)
end

s.mailboxes.each do |b|
  moves = b.messages("headers.subject.~" => "[.*]")
  mailbox_moves = {}
  moves.each do |m|
    name = /\[(.*)\]/.match(m.headers(:subject))[1]
    mailbox = s.mailboxes("INBOX/Mailing Lists/#{name}") || s.create_mailbox(name)
    mailbox_moves[mailbox] ||= []
    mailbox_moves[mailbox] << m
  end

  mailbox_moves.each do |k,v|
    puts "Moving the following into #{k}:"
    v.each { |m| puts m }
    #k.batch(:move => v)
  end
end

s.mailboxes("INBOX/Mailing Lists/%").each do |b|
  deletes = b.messages("headers.date.<" => Date.today - 7)
  puts "Delete the following from INBOX/Mailing Lists:"
  deletes.each { |d| puts d }
  #b.batch(:delete, deletes)
end

s.mailboxes("Deleted Items").each do |b|
  puts "Empty Deleted Items"
  b.batch(:delete => b.messages)
end

s.mailboxes.each { |b| b.expunge }

