require 'parser/current'

class RubyBackend

attr_accessor :file_descs

def file_changed(file)
  fd = @file_descs[file]
  fd.problems = run_check(file, fd.content)
end

def link_request(msg)
  file = msg.file
  data = [["Top", file, 1], ["Below", file, 100]]
  JEP::Schema::LinkResponse.new(
    :token => msg.token,
    :start => msg.pos,
    :end => msg.pos,
    :links => data.collect{|d|
      JEP::Schema::LinkTarget.new(
        :display => d[0],
        :file => d[1],
        :pos => d[2],
      )},
    :limitExceeded => false
  )
end

def completion_request(msg)
  file = msg.file
  data = (1..100).collect {|i| ["opt#{i}", "opt#{i}"] }
  JEP::Schema::CompletionResponse.new(
    :token => msg.token,
    :start => msg.pos,#-word_start.size,
    :end => msg.pos,
    :options => data.collect{|d|
      JEP::Schema::CompletionOption.new(
        :insert => d[0],
        :desc => d[1],
      )},
    :limitExceeded => false
  )
end

private

def run_check(file, text)
  problems = []
  parser = Parser::CurrentRuby.new
  parser.diagnostics.all_errors_are_fatal = false
  parser.diagnostics.consumer = lambda do |diag|
    problems << JEP::Schema::Problem.new(
      # dup since diag message is frozen
      :message => diag.message.dup,
      :line => diag.location.line,
      :severity => :error
    )
  end
  buffer = Parser::Source::Buffer.new('(string)')
  buffer.source = text
  begin
    parser.parse(buffer)
  rescue Parser::SyntaxError => e
    # some syntax error still cause exceptions, i.e. are fatal
    # however those were already reported to the consumer correctly
  end

  problems
end

end
