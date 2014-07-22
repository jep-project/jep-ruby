$:.unshift(File.dirname(__FILE__)+"/../lib")
require 'logger'
require 'jep/backend/service'
require 'jep/backend/message_handler'
require 'parser/current'

handler = JEP::Backend::MessageHandler.new(
  :content_checker => proc do |file, content|
    problems = []
    parser = Parser::CurrentRuby.new
    parser.diagnostics.all_errors_are_fatal = false
    parser.diagnostics.consumer = lambda do |diag|
      problems << {
        # dup since diag message is frozen
        :message => diag.message.dup,
        :line => diag.location.line,
        :severity => "error"
      }
    end
    buffer = Parser::Source::Buffer.new("dummy")
    buffer.source = content
    parser.parse(buffer)
    problems
  end
)
service = JEP::Backend::Service.new(handler, :logger => Logger.new($stdout), :timeout => 3600)
service.startup
service.receive_loop
