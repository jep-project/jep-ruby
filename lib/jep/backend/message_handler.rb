module JEP
module Backend

class MessageHandler

def initialize
  @file_contents = {}
end

def handle_Stop(msg, context)
  context.stop_service
end

def handle_ContentSync(msg, context)
  file = msg.object[:file]
  if file
    contents = @file_contents[file]
    start_index = (msg.object[:start] || "0").to_i
    end_index = (msg.object[:end] || "-1").to_i
    if contents
      contents[start_index..end_index] = msg.binary
    else
      if start_index == 0
        @file_contents[file] = binary
      else
        context.send_message(JEP::MessageHelper::Message.new(
          { :_message => "OutOfSync",
            :file => file }, 
          ""
        ))
      end
    end
  else
    # missing file property
  end
end

end

end
end

