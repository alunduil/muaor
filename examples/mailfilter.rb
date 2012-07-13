#!/bin/env ruby

require 'mail'
require 'optparse'
require 'date'

opts = { :protocol => :imap }
OptionParser.new do |o|
  o.on('-u', "--username USER", String, "Username to login with") { |u| opts[:username] = u }
  o.on("-H", "--hostname HOST", String, "Hostname to login to") { |h| opts[:hostname] = h }
  o.on("--protocol PROTO", String, "Protocol to connect with") { |p| opts[:protocol] = p.to_sym }
  o.on_tail("-h", "--help", "Show this message") { puts o; exit }
  o.parse!(ARGV)
end

$stdout.print "Password: "
$stdout.flush
`stty -echo`
opts[:password] = gets.chomp
`stty echo`
$stdout.puts ""

s = Mail::Server.new(opts[:protocol], opts[:hostname], opts[:username], opts[:password])

print "Expunging and flushing all changes ... "
s.mailboxes.each { |b| b.expunge }
puts "OK"

puts "Deleting all messages in all mailboxes with \"ssl\" in the To: header ..."
s.mailboxes.each do |b|
  print "  Deleting in #{b} ... "
  deletes = b.messages("headers.to.=" => "ssl")
  print "#{deletes.length} ... "
  b.batch(:delete => deletes)
  puts "OK"
end

#puts "Moving all messages with a mailing list designation (e.g. /\[.*?\]/) into an appropriate mailbox ..."
#s.mailboxes.each do |b|
#  puts "  Moving Messages from #{b}:"
#  moves = b.messages("headers.subject.~" => /\[.*?\]/)
#  Set.new(moves).classify { |m| m.headers(:subject).match(/\[(.*?)\]/)[1] }.each do |n, m|
#    mailbox = s.mailboxes("INBOX/Mailing Lists/#{n}") || s.create_mailbox("INBOX/Mailing Lists/#{n}")
#    print "    Moving Messages to #{mailbox} ... #{m.length} ... "
#    mailbox.batch(:move => m)
#    puts "OK"
#  end
#end

puts "Deleting all mailing list messages older than seven days ..."
s.mailboxes("INBOX/Mailing Lists/%").each do |b|
  print "  Deleting old messages in #{b} ... "
  deletes = b.messages("headers.date.<" => Date.today - 7)
  print "#{deletes.length} ... "
  b.batch(:delete => deletes)
  puts "OK"
end

print "Deleting all messages in \"Deleted Items\" ... "
s.mailboxes("Deleted Items").each do |b|
  b.batch(:delete => :all)
end
puts "OK"

print "Expunging and flushing all changes ... "
s.mailboxes.each { |b| b.expunge }
puts "OK"
