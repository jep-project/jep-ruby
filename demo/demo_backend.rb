$:.unshift(File.dirname(__FILE__)+"/../lib")
$:.unshift(File.dirname(__FILE__)+"/.")
require 'fox16'
require 'fox16/colors'
require 'logger'
require 'jep/backend/service'
require 'jep/schema'
require 'ruby_backend'

include Fox

class DemoBackend < FXMainWindow

FileData = Struct.new(:file, :tab, :text, :hilite, :content, :problems)
HiliteDesc = Struct.new(:start, :end, :step)
PopupDesc = Struct.new(:ticks)

attr_reader :popup

def initialize(app, backend)
  super(app, "JEP Demo Backend", nil, nil, DECOR_ALL, 0, 0, 850, 600, 0, 0)

  vframe = FXVerticalFrame.new(self,
    LAYOUT_SIDE_TOP|FRAME_NONE|LAYOUT_FILL_X|LAYOUT_FILL_Y)

  splitter = FXSplitter.new(vframe, (LAYOUT_SIDE_TOP|LAYOUT_FILL_X|
      LAYOUT_FILL_Y|SPLITTER_REVERSED|SPLITTER_TRACKING|SPLITTER_VERTICAL)) 

  @statusbar = FXStatusBar.new(vframe,
      LAYOUT_SIDE_BOTTOM|LAYOUT_FILL_X)
 
  @tabbook = FXTabBook.new(splitter,:opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_TOP)
  @problist = FXList.new(splitter,:opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_TOP)
  @file_data = {}
  @editor_font = FXFont.new(getApp, "courier")

  FXToolTip.new(app, TOOLTIP_PERMANENT)

  @popup = FXPopup.new(self)
  @complist = FXList.new(@popup,:opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_TOP)
  @popup_desc = PopupDesc.new

  backend.file_descs = @file_data
  @backend = backend

  app.addTimeout(100, :repeat => true) do |sender, sel, data|
    update_problem_tooltip
    if @popup_desc.ticks && @popup_desc.ticks > 0
      @popup_desc.ticks -= 1
      if @popup_desc.ticks == 0
        @popup.popdown
      end
    end
    @file_data.values.each do |fd|
      if fd.hilite.step > 0
        fd.hilite.step -= 1
        if fd.hilite.start > 0
          #fd.text.changeStyle(0, hilite.start, 1)
        end
        if fd.hilite.step > 0
          fd.text.changeStyle(fd.hilite.start, fd.hilite.end-fd.hilite.start, fd.hilite.step+1)
        else
          # reset the change highlighting and highlight errors
          fd.text.changeStyle(0, fd.text.length, fd.hilite.step+1)
          fd.problems.each do |p|
            lstart = fd.text.nextLine(0, p.line-1)
            fd.text.changeStyle(lstart, fd.text.lineEnd(lstart)-lstart, 11)
          end
        end
        if fd.hilite.end < fd.text.length
          #fd.text.changeStyle(hilite.end, fd.text.length-fd.hilite.end, 1)
        end
      end
    end
  end
end

def update_problem_tooltip
  fd = current_file_data
  if fd
    ed = fd.text 
    line = ed.countLines(0, ed.getPosAt(ed.cursorPosition[0], ed.cursorPosition[1])) + 1
    prob = fd.problems.find{|p| p.line == line}
    if prob
      ed.tipText = prob.message
    else
      ed.tipText = nil
    end
  end
end

def current_file_data
  if @tabbook.current >= 0
    @file_data.values.find{|fd| fd.tab == @tabbook.childAtIndex(@tabbook.current*2)}
  else
    nil
  end
end

def message_received(msg, context)
  # assume context is always the same (TODO)
  @context = context
  case msg
  when JEP::Schema::ContentSync
    handle_ContentSync(msg, context)
  when JEP::Schema::CompletionRequest
    handle_CompletionRequest(msg, context)
  when JEP::Schema::LinkRequest
    handle_LinkRequest(msg, context)
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

      fd.content = editor.extractText(0, editor.length)
      @backend.file_changed(file)
      update_problems(context)

      # hilite styles must be recreated when the content changes
      # otherwise the result is strange (e.g. red colored text when it should be black)
      editor.hiliteStyles = create_hilite_styles(editor)
    else
      context.send_message("OutOfSync")
    end
    select_tab(fd.tab)
  else
    tab = FXTabItem.new(@tabbook, File.basename(file), nil)
    tab.tipText = file
    textbox = FXHorizontalFrame.new(@tabbook,
        FRAME_SUNKEN|LAYOUT_FILL_X|LAYOUT_FILL_Y, 0,0,0,0, 0,0,0,0)
    editor = FXText.new(textbox, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|TEXT_READONLY)
    editor.styled = true
    editor.font = @editor_font

    editor.hiliteStyles = create_hilite_styles(editor)

    @tabbook.create
    @tabbook.recalc
    select_tab(tab)

    hilite = HiliteDesc.new(0, 0, 0)
    @file_data[file] = FileData.new(file, tab, editor, hilite)

    start_index = (msg.start || 0).to_i
    if start_index == 0
      editor.insertText(0, msg.data)
      hilite.start = 0
      hilite.end = msg.data.size
      hilite.step = 10
      @file_data[file].content = editor.extractText(0, editor.length)
      @backend.file_changed(file)
      update_problems(context)
    else
      context.send_message("OutOfSync")
    end
  end
end

def select_tab(tab)
  @tabbook.setCurrent(@tabbook.indexOfChild(tab)/2)
end

def handle_CompletionRequest(msg, context)
  fd = @file_data[msg.file]
  resp = @backend.completion_request(msg)
  if fd
    show_popup_list(fd.tab, fd.text, msg.pos, resp.options.collect{|o| o.insert})
  end
  context.send_message(resp)
end

def handle_LinkRequest(msg, context)
  fd = @file_data[msg.file]
  resp = @backend.link_request(msg)
  if fd
    show_popup_list(fd.tab, fd.text, msg.pos, resp.links.collect{|o| o.display})
  end
  context.send_message(resp)
end

def show_popup_list(tab, text, pos, list)
  select_tab(tab)
  if !text.positionVisible?(pos)
    text.makePositionVisible(pos)
  end

  # cursor is only visible when window is active
  # also, the cursor disappears when new text is inserted
  #text.setCursorPos(pos)

  x, y = pos_to_coords(text, pos)

  # self is the main window
  x, y = translateCoordinatesFrom(text, x, y)

  @complist.clearItems
  list.each do |l|
    @complist.appendItem(l)
  end

  @popup.popup(text, self.x+x, self.y+y, 300, 200)
  @popup_desc.ticks = 30
end

def pos_to_coords(text, pos)
  x = 0
  y = 0
  while y < text.height
    break if text.getPosAt(0, y+1) > pos || text.getPosAt(0, y) == text.getPosAt(0, y+100)
    y += 1
  end
  while x < text.width
    break if text.getPosAt(x, y) >= pos
    x += 1
  end
  [x, y]
end

def create_hilite_styles(editor)
  styles = (0..9).collect do |i|
    s = FXHiliteStyle.from_text(editor)
    s.normalBackColor = FXRGB(255, 255, 25*(10-i)+5)
    s.normalForeColor = FXRGB(0, 0, 0)
    s
  end

  error_style = FXHiliteStyle.from_text(editor)
  error_style.normalBackColor = FXRGB(255, 200, 200)
  error_style.normalForeColor = FXRGB(255, 0, 0)
  styles <<= error_style

  styles
end

def update_problems(context)
  @problist.clearItems
  @file_data.values.collect do |fd|
    fd.problems.each do |p|
      @problist.appendItem("#{p.severity.to_s.upcase} | #{File.basename(fd.file)}:#{p.line} | #{p.message}")
    end
  end
  @statusbar.statusLine.normalText = "#{@problist.numItems} problems"
  context.send_message(JEP::Schema::ProblemUpdate.new(
    :fileProblems => @file_data.values.collect do |fd|
      JEP::Schema::FileProblems.new(
        :file => fd.file,
        :problems => fd.problems
      )
    end
    ))
end

end

application = FXApp.new("JEP", "Demo")
backend = RubyBackend.new
main_window = DemoBackend.new(application, backend)

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

