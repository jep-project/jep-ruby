require 'jep/frontend/problem_list'

module JEP
module Frontend

class DefaultHandler

attr_accessor :connector

def initialize(options={})
  @problem_list = ProblemList.new
  @on_problem_change = options[:on_problem_change] || ->(probs){}
end

def handle_ProblemUpdate(msg)
  @problem_list.update(msg)
  @on_problem_change.call(@problem_list.get_problems)
end

def sync_file(file, content)
  @connector.send_message("ContentSync", {"file" => file}, content)
end

end

end
end
