$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'logger'
require 'jep/schema'
require 'jep/frontend/connector_manager'

class ConnectionTest < Test::Unit::TestCase

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

  con6 = man.connector_for_file("plain/file_plain")
  assert_equal con.object_id, con6.object_id

  con7 = man.connector_for_file("plain/file_plain.txt")
  assert_equal con.object_id, con7.object_id

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
    JEP::Frontend::Connector.new(config,
    :logger => @logger)
  end

  con = man.connector_for_file("plain/file.hang_on_startup")
  assert_not_nil con

  con.start
  con.work :for => 1, :while => ->{ !con.connected? }
  assert !con.connected?

  con.stop
  con.work :for => 1, :while => ->{ con.backend_running? }
  assert !con.backend_running?
end

def test_backend_connection_problem
  man = JEP::Frontend::ConnectorManager.new do |config|
    JEP::Frontend::Connector.new(config,
    :logger => @logger)
  end

  con = man.connector_for_file("plain/file.cant_connect")
  assert_not_nil con

  con.start
  con.work :for => 1, :while => ->{ !con.connected? }
  assert !con.connected?

  con.stop
  con.work :for => 1, :while => ->{ con.backend_running? }
  assert !con.backend_running?
end

def test_backend_stop_problem
  man = JEP::Frontend::ConnectorManager.new do |config|
    JEP::Frontend::Connector.new(config,
    :logger => @logger)
  end

  con = man.connector_for_file("plain/file.cant_stop")
  assert_not_nil con

  con.start
  con.work :for => 1, :while => ->{ !con.connected? }
  assert con.connected?

  con.stop(:wait => 1)
  con.work :for => 1, :while => ->{ con.backend_running? }
  assert !con.backend_running?
end

def test_send
  man = JEP::Frontend::ConnectorManager.new do |config|
    JEP::Frontend::Connector.new(config)
  end

  con = man.connector_for_file("plain/file.plain")
  assert_not_nil con

  assert_equal :not_connected, con.send_message(JEP::Schema::ContentSync.new)

  con.start
  con.work :for => 5, :while => ->{ !con.connected? }

  assert con.connected?

  assert_equal :success, con.send_message(JEP::Schema::ContentSync.new)
end

def test_pingpong
  handler = Object.new
  class << handler
    attr_accessor :got_pong
    def message_received(msg)
      @got_pong = true if msg.is_a?(JEP::Schema::OutOfSync)
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

  con.start
  con.work :for => 5, :while => ->{ !con.connected? }

  assert con.connected?

  res = con.send_message(JEP::Schema::ContentSync.new)
  assert_equal :success, res

  con.work :for => 1, :while => ->{ !handler.got_pong }
  assert handler.got_pong
end

def test_stop
  man = JEP::Frontend::ConnectorManager.new do |config|
    JEP::Frontend::Connector.new(config,
      :logger => @logger)
  end

  con = man.connector_for_file("plain/file.plain")
  assert_not_nil con

  assert_equal :not_started, con.stop

  con.start
  con.work :for => 5, :while => ->{ !con.connected? }

  assert con.connected?

  assert_equal :success, con.stop
  assert !con.connected?
  assert con.read_service_output_lines.any?{|l| l =~ /JEP service, stopping now/}
end

def test_restart
  man = JEP::Frontend::ConnectorManager.new do |config|
    JEP::Frontend::Connector.new(config,
      :logger => @logger)
  end

  con = man.connector_for_file("plain/file.plain")

  con.start
  con.work :for => 5, :while => ->{ !con.connected? }
  assert con.connected?

  assert_equal :success, con.stop
  assert !con.connected?
  assert con.read_service_output_lines.any?{|l| l =~ /JEP service, stopping now/}

  con.start
  con.work :for => 5, :while => ->{ !con.connected? }
  assert con.connected?
end

def test_read_output_lines_with_logger
  man = JEP::Frontend::ConnectorManager.new do |config|
    JEP::Frontend::Connector.new(config,
      :logger => @logger,
      :log_service_output => true)
  end

  con = man.connector_for_file("plain/file.plain")

  con.start
  con.work :for => 5, :while => ->{ !con.connected? }

  con.send_message(JEP::Schema::OutOfSync.new)
  con.work :for => 0.5

  assert con.read_service_output_lines.any?{|l| l =~ /received.+OutOfSync/}
  con.stop
end

end

