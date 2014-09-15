module JEP

class CompletionList

attr_accessor :start_pos, :end_pos
attr_accessor :limit_exceeded
attr_accessor :options

CompletionOption = Struct.new(:display, :desc, :semantics, :extensionId)

def initialize(message=nil)
  from_message(message) if message
end

def from_message(message)
  @start_pos = message.object["start"]
  @end_pos = message.object["end"]
  @limit_exceeded = message.object["limitExceeded"] == true
  @options = []
  opts = message.object["options"]
  if opts
    @options = opts.collect do |o|
      CompletionOption.new(o["display"], o["desc"], o["semantics"].to_sym, o["extensionId"])
    end
  end
end

end

end
