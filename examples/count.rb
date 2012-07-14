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
s.mailboxes.each { |b| puts "#{b} -> #{b.count(:messages)}" }

