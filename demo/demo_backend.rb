$:.unshift(File.dirname(__FILE__)+"/../lib")
require 'fox16'
require 'fox16/colors'
require 'logger'
require 'jep/backend/service'
require 'jep/schema'
require 'parser/current'

include Fox

class DemoBackend < FXMainWindow

FileData = Struct.new(:file, :tab, :text, :hilite)
HiliteDesc = Struct.new(:start, :end, :step)

def initialize(app)
  super(app, "JEP Demo Backend", nil, nil, DECOR_ALL, 0, 0, 850, 600, 0, 0)
  contents = FXHorizontalFrame.new(self,
    LAYOUT_SIDE_TOP|FRAME_NONE|LAYOUT_FILL_X|LAYOUT_FILL_Y|PACK_UNIFORM_WIDTH)
  @tabbook = FXTabBook.new(contents,:opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_RIGHT)
  @file_data = {}
  @editor_font = FXFont.new(getApp, "courier")
end

def message_received(msg, context)
  # assume context is always the same (TODO)
  @context = context
  case msg
  when JEP::Schema::ContentSync
    handle_ContentSync(msg, context)
  when JEP::Schema::CompletionRequest
    handle_CompletionRequest(msg)
  when JEP::Schema::Shutdown
    context.stop_service
    getApp.exit
  end
end

def handle_ContentSync(msg, context)
  file = msg.file
  fd = @file_data[file]
  if fd
    editor = fd.text
    start_index = (msg.start || 0).to_i
    end_index = (msg.end || editor.length).to_i
    if start_index >= 0 && start_index <= editor.length &&
       end_index >= start_index && end_index <= editor.length
      editor.replaceText(start_index, end_index-start_index, msg.data)
      fd.hilite.start = start_index
      fd.hilite.end = start_index+msg.data.size
      fd.hilite.step = 10
      #run_check(editor.extractText(0, editor.length))
    else
      context.send_message("OutOfSync")
    end
    @tabbook.setCurrent(@tabbook.indexOfChild(fd.tab)/2)
  else
    tab = FXTabItem.new(@tabbook, File.basename(file), nil)
    textbox = FXHorizontalFrame.new(@tabbook,
        FRAME_SUNKEN|LAYOUT_FILL_X|LAYOUT_FILL_Y, 0,0,0,0, 0,0,0,0)
    editor = FXText.new(textbox, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y)
    editor.styled = true
    editor.font = @editor_font

    editor.hiliteStyles = (0..9).collect do |i|
      s = FXHiliteStyle.from_text(editor)
      s.normalBackColor = FXRGB(255, 255, 25*(10-i)+5)
      s.normalForeColor = FXColor::Black
      s
    end

    @tabbook.create
    @tabbook.recalc
    @tabbook.setCurrent(@tabbook.indexOfChild(tab)/2)

    hilite = HiliteDesc.new(0, 0, 0)
    @file_data[file] = FileData.new(file, tab, editor, hilite)

    getApp.addTimeout(200, :repeat => true) do |sender, sel, data|
      @file_data.values.each do |fd|
        if fd.hilite.step > 0
          fd.hilite.step -= 1
          if hilite.start > 0
            #fd.text.changeStyle(0, hilite.start, 1)
          end
          fd.text.changeStyle(fd.hilite.start, fd.hilite.end-fd.hilite.start, fd.hilite.step+1)
          if fd.hilite.end < fd.text.length
            #fd.text.changeStyle(hilite.end, fd.text.length-fd.hilite.end, 1)
          end
        end
      end
    end

    start_index = (msg.start || 0).to_i
    if start_index == 0
      editor.insertText(0, msg.data)
      hilite.start = 0
      hilite.end = msg.data.size
      hilite.step = 10
    else
      context.send_message("OutOfSync")
    end
  end
end

# def run_check(text)
#   parser = Parser::CurrentRuby.new
#   parser.diagnostics.consumer = lambda do |diag|
#     puts diag.inspect
#   end
#   buffer = Parser::Source::Buffer.new('(string)')
#   buffer.source = text
#   parser.parse(buffer)
# end

end

application = FXApp.new("JEP", "Demo")
main_window = DemoBackend.new(application)

service = JEP::Backend::Service.new(main_window, :logger => Logger.new($stdout))
service.startup
on_timeout = proc do
  service.receive
  application.addTimeout(100, on_timeout)
end
application.addTimeout(100, on_timeout)

application.create
main_window.show(PLACEMENT_SCREEN)
application.run

