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
  @response_messages = {}
  @response_timeout = options[:response_timeout] || 5
end

def message_received(msg)
  case msg
  when Schema::ProblemUpdate
    @problem_tracker.update(msg)
  when Schema::CompletionResponse, Schema::LinkResponse
    handle_response_message(msg)
  end
end

def problems_changed(file)
  @on_problem_change.call(@problem_tracker.problems_by_file)
end

# Send update for +file+ containing +content+.
#
# options:
#   start: update region start index
#   end update region end index
#
def sync_file(file, content, options={})
  @connector.send_message(Schema::ContentSync.new(
    :file => file, 
    :data => content,
    :start => options[:start], 
    :end => options[:end]))
end

# Request the completion options for +file+ and +pos+.
# Returns a token which must be used when calling +request_result+
# to poll for the result.
#
# options:
#   limit: max number of options to be returned
#
def completion_request(file, pos, options={})
  token = Time.now.to_f.to_s
  @response_messages[token] = Time.now
  @connector.send_message(Schema::CompletionRequest.new(
    :file => file, 
    :pos => pos,
    :limit => options[:limit],
    :token => token))
  token
end

# Request the link targets for +file+ and +pos+.
# Returns a token which must be used when calling +request_result+
# to poll for the result.
#
# options:
#   limit: max number of options to be returned
#
def link_request(file, pos, options={})
  token = Time.now.to_f.to_s
  @response_messages[token] = Time.now
  @connector.send_message(Schema::LinkRequest.new(
    :file => file, 
    :pos => pos,
    :limit => options[:limit],
    :token => token))
  token
end

# Generic method to poll for the result of a request.
# The result shows whether the request is :pending, a :timeout has occurred,
# the token is :invalid or on success it returns the response object.
def request_result(token)
  resp = @response_messages[token]
  if resp
    if resp.is_a?(Time)
      if Time.now - resp < @response_timeout
        :pending
      else
        @response_messages.delete(token)
        :timeout
      end
    else
      @response_messages.delete(token)
      resp
    end
  else
    :invalid
  end
end

private

# Generic handler for all kinds of response messages
# TODO: check for the expected response message type
def handle_response_message(msg)
  req =  @response_messages[msg.token]
  if req
    if req.is_a?(Time) && (Time.now - req < @response_timeout)
      @response_messages[msg.token] = msg
    else
      @connector.log(:warn, "response too late: #{msg.class}")
    end
  else
    @connector.log(:error, "unexpected token: #{msg.token}")
  end
end

end

end
end
