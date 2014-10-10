require 'jep/frontend/problem_tracker'
require 'jep/schema'
#require 'jep/frontend/completion_list'

module JEP
module Frontend

class DefaultHandler

attr_accessor :connector

def initialize(options={})
  @problem_tracker = ProblemTracker.new
  @problem_tracker.add_change_listener(method(:problems_changed))
  @on_problem_change = options[:on_problem_change] || ->(probs){}
  @completion_requests = {}
  @completion_timeout = options[:completion_timeout] || 5
end

def message_received(msg)
  case msg
  when Schema::ProblemUpdate
    @problem_tracker.update(msg)
  when Schema::CompletionResponse
    handle_completion_response(msg)
  end
end

def problems_changed(file)
  @on_problem_change.call(@problem_tracker.problems_by_file)
end

def sync_file(file, content)
  @connector.send_message(Schema::ContentSync.new(:file => file, :binary => content))
end

# Request a CompletionList object for +file+ and +pos+.
# Returns a token which must be used when calling +completion_result+
# to poll for the result.
#
# options:
#   limit: max number of options to be returned
#
def completion_request(file, pos, options={})
  token = Time.now.to_f.to_s
  @completion_requests[token] = Time.now
  @connector.send_message(Schema::CompletionRequest.new(
    :file => file, 
    :pos => pos,
    :limit => options[:limit],
    :token => token))
  token
end

# Frontends use this method to poll for the results of a completion request.
# The result shows whether the completion is :pending, a :timeout has occurred,
# the token is :invalid or on success it returns a CompletionResponse object.
def completion_result(token)
  req = @completion_requests[token]
  if req
    if req.is_a?(Time)
      if Time.now - req < @completion_timeout
        :pending
      else
        @completion_requests.delete(token)
        :timeout
      end
    else
      @completion_requests.delete(token)
      req
    end
  else
    :invalid
  end
end

def handle_completion_response(msg)
  req =  @completion_requests[msg.token]
  if req
    if req.is_a?(Time) && (Time.now - req < @completion_timeout)
      @completion_requests[msg.token] = msg
    else
      @connector.log(:warn, "CompletionResponse: response too late")
    end
  else
    @connector.log(:error, "CompletionResponse: unexpected token")
  end
end

end

end
end
