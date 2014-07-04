$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'logger'
require 'jep/frontend/connector_manager'
require 'jep/frontend/default_handler'

class DefaultHandlerTest < Test::Unit::TestCase

def setup
  @logger = Logger.new($stdout)
  class << @logger
    def format_message(severity, timestamp, progname, msg)
      "#{severity} #{msg}\n"
    end
  end
end

def test_connector_identity
  problems = []
  handler = JEP::Frontend::DefaultHandler.new(
    :on_problem_change => ->(probs) { problems = probs })

  man = JEP::Frontend::ConnectorManager.new do |config|
    con = JEP::Frontend::Connector.new(config, 
      :logger => @logger,
      :log_service_output => true,
      :message_handler => handler)
    handler.connector = con
    con
  end

  con = man.connector_for_file("plain/file.probs")

  con.start
  con.work :for => 5, :while => ->{ !con.connected? }
  assert con.connected?

  handler.sync_file("plain/file.probs", "xxx")

  con.work :for => 5, :while => ->{ problems.size == 0 }

  assert_equal 2, problems.size
end

end
