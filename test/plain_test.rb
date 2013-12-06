$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'logger'
require 'jep/frontend/connector_manager'

class PlainTest < Test::Unit::TestCase

def setup
  @logger = Logger.new($stdout)
  class << @logger
    def format_message(severity, timestamp, progname, msg)
      "#{severity} #{msg}\n"
    end
  end
end

def test_connector_identity
  man = JEP::Frontend::ConnectorManager.new do |config|
    JEP::Frontend::Connector.new(config)
  end

  con = man.connector_for_file("plain/file.plain")

  con2 = man.connector_for_file("plain/file.plain")
  assert_equal con.object_id, con2.object_id

  con3 = man.connector_for_file("plain/file2.plain")
  assert_equal con.object_id, con3.object_id

  # different extension
  con4 = man.connector_for_file("plain/file.plain2")
  assert_equal con.object_id, con4.object_id

  # different .jep file
  con5 = man.connector_for_file("plain2/file.plain")
  assert_not_equal con.object_id, con5.object_id
end

def test_non_existing_file
  man = JEP::Frontend::ConnectorManager.new do |config|
    JEP::Frontend::Connector.new(config)
  end

  con = man.connector_for_file("plain/non_existing_file")
  assert_nil con
end

def test_backend_startup_problem
  man = JEP::Frontend::ConnectorManager.new do |config|
    JEP::Frontend::Connector.new(config)
  end
  con = man.connector_for_file("plain/file.hang_on_startup")
  assert_not_nil con
  assert_equal :success, con.connect
end

def test_send
  man = JEP::Frontend::ConnectorManager.new do |config|
    JEP::Frontend::Connector.new(config)
  end

  con = man.connector_for_file("plain/file.plain")
  assert_not_nil con

  assert_equal :not_connected, con.send_message("something")

  assert_equal :success, con.connect

  assert_equal :success, con.send_message("something")
end

def test_pingpong
  handler = Object.new
  class << handler
    attr_accessor :got_pong
    def handle_pong(msg)
      @got_pong = true
    end
  end

  man = JEP::Frontend::ConnectorManager.new do |config|
    JEP::Frontend::Connector.new(config, 
      :message_handler => handler,
      :logger => @logger,
      :log_service_output => true)
  end

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
  man = JEP::Frontend::ConnectorManager.new do |config|
    JEP::Frontend::Connector.new(config,
      :logger => @logger)
  end

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

