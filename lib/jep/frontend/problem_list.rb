module JEP
module Frontend

class ProblemList

Problem = Struct.new(:file, :line, :message, :severity)

attr_reader :problems

def initialize
  @problems = []
end

def update(message)
  raise ArgumentError.new("not a ProblemUpdate message") \
    unless message.type == "ProblemUpdate"
  raise ArgumentError.new("can't handle partial problem update") \
    if message.object["partial"]
  probs = message.object["fileProblems"]
  if probs.is_a?(Array)
    @problems = probs
  else
    # ignoring message
    @problems = []
  end
end

def get_problems
  result = []
  @problems.each do |fp|
    file = fp["file"]
    fp["problems"].each do |p|
      result << Problem.new(file, p["line"], p["message"], p["severity"])
    end
  end
  result
end

end

end
end

