require 'helper'

class TestFunctionalMail < Test::Unit::TestCase
  def setup
    puts "Mail Host: "
    host = gets.chomp

    puts "Username: "
    username = gets.chomp

    puts "Password: "
    `stty -echo`
    password = gets.chomp
    `stty echo`

    @server = Mail::Account.new(host, username, password)
  end

  def test_capabilities_class
    assert_equal(Array, @server.capabilities)
  end

  def test_capabilities_elements_class
    @server.capabilities.each { |c| assert_equal(Symbol, c) }
  end

  def test_authentication_mechanisms_class
    assert_equal(Array, @server.authentication_mechanisms)
  end

  def test_authentication_mechanisms_elements_class
    @server.authentication_mechanisms.each { |m| assert_equal(Symbol, m) }
  end

  def test_authentication_mechanisms_includes_plain
    assert_equal(true, @server.authentication_mechanisms.included? :plain)
  end
end

