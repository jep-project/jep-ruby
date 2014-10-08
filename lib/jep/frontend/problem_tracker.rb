module JEP
module Frontend

# Keeps an up to date list of problems by tracking problem update messages.
# In particular, it takes care of partial problem updates.
class ProblemTracker

def initialize
  @problems_by_file = {}
  @listeners = []
end

def update(message)
  raise ArgumentError.new("not a ProblemUpdate message") \
    unless message.is_a?(JEP::Schema::ProblemUpdate)
  if !message.partial
    @problems_by_file = {}
  end
  message.fileProblems.each do |fp|
    @problems_by_file[fp.file] ||= []
    starti = fp.start || 0
    endi = fp.end || @problems_by_file[fp.file].size
    endi = starti if endi < starti
    @problems_by_file[fp.file][starti, endi-starti] = fp.problems
    @listeners.each do |l|
      l.call(fp.file)
    end
  end
end

def problems_by_file
  @problems_by_file
end

def add_change_listener(listener)
  @listeners << listener
end

def remove_change_listener(listener)
  @listeners.delete(listener)
end

end

end
end

