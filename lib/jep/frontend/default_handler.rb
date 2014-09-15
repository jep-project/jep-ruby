require 'jep/frontend/problem_list'
require 'jep/frontedn/completion_list'

module JEP
module Frontend

class DefaultHandler

attr_accessor :connector

def initialize(options={})
  @problem_list = ProblemList.new
  @on_problem_change = options[:on_problem_change] || ->(probs){}
  @completion_requests = {}
end

def handle_ProblemUpdate(msg)
  @problem_list.update(msg)
  @on_problem_change.call(@problem_list.get_problems)
end

def sync_file(file, content)
  @connector.send_message("ContentSync", {"file" => file}, content)
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
  @connector.send_message("CompletionRequest", {
    "file" => file, 
    "pos" => pos,
    "limit" => options[:limit],
    "token" => token})
  token
end

# Frontends use this method to poll for the results of a completion request.
# The result shows whether the completion is :pending, a :timeout has occurred,
# the token is :invalid or on success it returns a CompletionList object.
def completion_result(token)
  req = @completion_requests[token]
  if req
    if req.is_a?(Time)
      if Time.now - req < CompletionRequestTimeout
        :pending
      else
        @completion_requests.delete[token]
        :timeout
      end
    else
      @completion_requests.delete[token]
      req
    end
  else
    :invalid
  end
end

def handle_CompletionResponse(msg)
  token = msg.object["token"]
  req =  @completion_requests[token]
  if req
    if req.is_a?(Time) && (Time.now - req < CompletionRequestTimeout)
      @completion_requests[token] = CompletionList.new(msg)
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
