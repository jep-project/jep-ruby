$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'logger'
require 'jep/frontend/connector_manager'

class PlainTest < Test::Unit::TestCase

def test_plain
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

  i = 0
  while !handler.got_pong && i < 10
    sleep(0.1)
    con.resume
    i += 1
  end
  assert handler.got_pong
end

end

