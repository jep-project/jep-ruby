$:.unshift(File.dirname(__FILE__)+"/../../lib")
require 'logger'
require 'jep/backend/service'

$stdout.sync = true

handler = Object.new
class << handler
  def message_received(msg, context)
    if msg["ping"]
      context.send_message({"pong" => true})
    end
  end
end

logger = Logger.new($stdout)
class << logger
  def format_message(severity, timestamp, progname, msg)
    "#{severity} #{msg}\n"
  end
end

# short timeout ensures that the backend stops by itself
service = JEP::Backend::Service.new(handler, :timeout => 3, :logger => logger)

if ARGV.include?("nostop")
  class << service
    def stop
      # do not stop
    end
  end
end

service.startup
service.receive_loop
