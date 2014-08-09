module JEP
module Backend

class MessageHandler

def initialize(options={})
  @content_checker = options[:content_checker]
  @file_contents = {}
end

def handle_Stop(msg, context)
  context.stop_service
end

def handle_ContentSync(msg, context)
  file = msg.object["file"]
  if file
    contents = @file_contents[file]
    start_index = (msg.object["start"] || "0").to_i
    end_index = (msg.object["end"] || "-1").to_i
    if contents
      contents[start_index...end_index] = msg.binary
      content_changed(file, contents, context)
    else
      if start_index == 0
        @file_contents[file] = msg.binary
        content_changed(file, @file_contents[file], context)
      else
        context.send_message("OutOfSync",
          { :file => file }
        )
      end
    end
  else
    # missing file property
  end
end

private

def content_changed(file, content, context)
  if @content_checker
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

