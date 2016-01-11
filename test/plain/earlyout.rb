$:.unshift(File.dirname(__FILE__)+"/../../lib")
require 'logger'
require 'jep/backend/message_handler'
require 'jep/backend/service'

$stdout.sync = true

handler = JEP::Backend::MessageHandler.new()

service = JEP::Backend::Service.new(handler, :timeout => 3)
puts "output before 'JEP service, listening on port ...'"
service.startup
service.receive_loop

