$:.unshift(File.dirname(__FILE__)+"/../lib")
require 'fox16'
require 'logger'
require 'jep/backend/service'
require 'parser/current'

include Fox

class DemoBackend < FXMainWindow

def initialize(app)
  super(app, "JEP Demo Backend", nil, nil, DECOR_ALL, 0, 0, 850, 600, 0, 0)
  contents = FXHorizontalFrame.new(self,
    LAYOUT_SIDE_TOP|FRAME_NONE|LAYOUT_FILL_X|LAYOUT_FILL_Y|PACK_UNIFORM_WIDTH)
  @tabbook = FXTabBook.new(contents,:opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_RIGHT)
  @tab_per_file = {}
  @editor_per_file = {}
end

def handle_ContentSync(msg, context)
  file = msg.object["file"]
  tab = @tab_per_file[file]
  editor = @editor_per_file[file]
  if tab
    start_index = (msg.object["start"] || 0).to_i
    end_index = (msg.object["end"] || editor.length).to_i
    if start_index >= 0 && start_index <= editor.length &&
       end_index >= start_index && end_index <= editor.length
      editor.replaceText(start_index, end_index-start_index, msg.data)
      run_check(editor.extractText(0, editor.length))
    else
      context.send_message("OutOfSync")
    end
  else
    tab = FXTabItem.new(@tabbook, File.basename(file), nil)
    textbox = FXHorizontalFrame.new(@tabbook,
        FRAME_SUNKEN|LAYOUT_FILL_X|LAYOUT_FILL_Y, 0,0,0,0, 0,0,0,0)
    editor = FXText.new(textbox, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y)
    @tabbook.create
    @tabbook.recalc
    @tab_per_file[file] = tab
    @editor_per_file[file] = editor

    start_index = (msg.object["start"] || 0).to_i
    if start_index == 0
      editor.insertText(0, msg.data)
    else
      context.send_message("OutOfSync")
    end
  end
  @tabbook.setCurrent(@tabbook.indexOfChild(tab))
end

def handle_Stop(msg, context)
  getApp.exit
end

def run_check(text)
  parser = Parser::CurrentRuby.new
  parser.diagnostics.consumer = lambda do |diag|
    puts diag.inspect
  end
  buffer = Parser::Source::Buffer.new('(string)')
  buffer.source = text
  parser.parse(buffer)
end

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

