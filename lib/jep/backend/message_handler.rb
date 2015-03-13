require 'jep/content_tracker'

module JEP
module Backend

class MessageHandler

def initialize(options={})
  @content_checker = options[:content_checker]
  @completio_provider = options[:completion_provider]
  @file_contents = {}
  @content_tracker = ContentTracker.new
  @content_tracker.add_change_listener(method(:content_changed))
end

def message_received(msg, context)
  # assume context is always the same (TODO)
  @context = context
  case msg
  when Schema::ContentSync
    @content_tracker.update(msg)
  when Schema::CompletionRequest
    handle_CompletionRequest(msg)
  when Schema::Shutdown
    context.stop_service
  end
end

def handle_CompletionRequest(msg)
  content = @content_tracker.content(file)
  if content
    if @completion_provider
      @completion_provider.call(file, content, msg.pos)
    else
      @context.log(:info, "CompletionRequest: no provider registered")
    end
  else
    @context.log(:error, "CompletionRequest: unknown file '#{file}'")
  end
end

private

def content_changed(file)
  if @content_checker
    content = @content_tracker.content(file)
    problems = @content_checker.call(file, content)
    @context && @context.send_message(Schema::ProblemUpdate.new(
      :fileProblems => [
        Schema::FileProblems.new(
          :file => file,
          :problems => problems
        )
      ]))
  end
end

end

end
end

