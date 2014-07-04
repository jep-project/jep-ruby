$:.unshift(File.dirname(__FILE__)+"/../../lib")
require 'logger'
require 'jep/backend/message_handler'
require 'jep/backend/service'

$stdout.sync = true

handler = JEP::Backend::MessageHandler.new(
  :content_checker => ->(file, content) {
    [
      {
        :message => "message 1",
        :line => 10,
        :severity => "error"
      },
      {
        :message => "message 2",
        :line => 13,
        :severity => "warning"
      }
    ]
  })

service = JEP::Backend::Service.new(handler, :timeout => 3)
service.startup
service.receive_loop
