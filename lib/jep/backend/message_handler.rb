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
  when Schema::Shutdown
    context.stop_service
  end
end

def handle_CompletionRequest(msg, context)
  file = msg.object["file"]
  if file
    contents = @file_contents[file]
    if contents
      pos = msg.object["pos"]
      if pos
        if @completion_provider
          @completion_provider.call(file, content, pos)
        else
          context.log(:info, "CompletionRequest: no provider registered")
        end
      else
        context.log(:error, "CompletionRequest: missing position property")
      end
    else
      context.log(:error, "CompletionRequest: unknown file #{file}")
    end
  else
    context.log(:error, "CompletionRequest: missing file property")
  end
end

private

def content_changed(file, context)
  if @content_checker
    content = @content_tracker.content_by_file(file)
    problems = @content_checker.call(file, content)
    context.send_message("ProblemUpdate", {
      :fileProblems => [{
        :file => file,
        :problems => problems
      }]
    })
  end
end

end

end
end

