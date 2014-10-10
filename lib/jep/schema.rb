require 'jep/schema_base'

module JEP

# Schema definition according to the JEP specification.
# Ruby classes with proper accessor methods will be derived from this.
module Schema

# Backend Alive Message

message "BackendAlive"

# Backend Shutdown

message "Shutdown"

# Semantics

enum "SemanticType", [
  :comment,
  :comment,
  :type,
  :string,
  :number,
  :identifier,
  :keyword,
  :label,
  :link,
  :special1,
  :special2,
  :special3,
  :special4,
  :special5
]

# Content Synchronization

message "ContentSync" do
  prop "file", String
  prop "start", [0,1], Integer
  prop "end", [0,1], Integer
  binary 
end

message "OutOfSync" do
  prop "file", String
end

# Problem Markers

enum "SeverityEnum", [
  :debug, 
  :info, 
  :warn, 
  :error, 
  :fatal
]

struct "Problem" do
  prop "message", String
  prop "severity", SeverityEnum
  prop "line", Integer
end

struct "FileProblems" do
  prop "file", String
  prop "problems", [0,:*], Problem
  prop "total", [0,1], Integer
  prop "start", [0,1], Integer
  prop "end", [0,1], Integer
end

message "ProblemUpdate" do
  prop "fileProblems", [0,:*], FileProblems
  prop "partial", [0,1], Boolean
end

# Content Completion

message "CompletionRequest" do
  prop "file", String
  prop "pos", Integer
  prop "limit", [0,1], Integer
  prop "token", String
end

struct "CompletionOption" do
  prop "insert", String
  prop "display", [0,1], String
  prop "desc", [0,1], String
  prop "semantics", [0,1], SemanticType
  prop "extensionId", [0,1], String
end

message "CompletionResponse" do
  prop "token", String
  prop "start", Integer
  prop "end", Integer
  prop "options", [0,:*], CompletionOption
  prop "limitExceeded", Boolean
end

message "CompletionInvocation" do
  prop "extensionId", String
end

end

end

