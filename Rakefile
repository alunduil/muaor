# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Task.new do |gem|
  gem.name = "muaor"
  gem.homepage = "http://github.com/alunduil/muaor"
  gem.license = "GPL-2"
  gem.summary = %Q{Mail User Agent Objects for Ruby}
  gem.description = %Q{A higher level resource oriented MUA implementation for crafting MUAs, MUA proxies, mail filtering robots, a fetchmail replacement or anything else that requires this type of manipulation of mail.}
  gem.email = "alunduil@alunduil.com"
  gem.authors = ["Alex Brandt"]
  # Dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.test_files = Dir.glob('test/**/test_*.rb')
  test.verbose = true
end

task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : "9999"

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "muaor #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

