$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'logger'
require 'jep/frontend/connector_manager'

class PlainTest < Test::Unit::TestCase

def test_send
  man = JEP::Frontend::ConnectorManager.new(nil, 
    :logger => Logger.new($stdout),
    :keep_outfile => true)
  con = man.connector_for_file("plain/file.plain")
  assert_not_nil con

  assert_equal :not_connected, con.send_message("something")

  res = con.connect
  assert_equal :success, res

  res = con.send_message("something")
  assert_equal :success, res
end

def test_pingpong
  handler = Object.new
  class << handler
    attr_accessor :got_pong
    def handle_pong(msg)
      @got_pong = true
    end
  end

  man = JEP::Frontend::ConnectorManager.new(handler, 
    :logger => Logger.new($stdout),
    :keep_outfile => true)
  con = man.connector_for_file("plain/file.plain")
  assert_not_nil con

  res = con.connect
  assert_equal :success, res

  res = con.send_message("ping")
  assert_equal :success, res

  10.times do 
    sleep(0.1)
    con.resume
    break if handler.got_pong
  end
  assert handler.got_pong
end

def test_stop
  man = JEP::Frontend::ConnectorManager.new(nil, 
    :logger => Logger.new($stdout),
    :keep_outfile => true)
  con = man.connector_for_file("plain/file.plain")
  assert_not_nil con

  assert_equal :not_connected, con.stop

  res = con.connect
  assert_equal :success, res

  res = con.stop
  assert_equal :success, res

  stopped = false
  10.times do
    sleep(0.1)
    if con.read_service_output_lines.any?{|l| l =~ /JEP service, stopping now/}
      stopped = true
      break
    end
  end
  assert stopped
end

end

