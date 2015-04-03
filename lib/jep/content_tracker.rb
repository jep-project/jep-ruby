require 'jep/schema'

module JEP

# Keeps the up-to-date file contents by tracking ContentSync messages.
# In particular, it handles partial content updates.
class ContentTracker

def initialize
  @content_by_file = {}
  @listeners = []
end

def update(message)
  raise ArgumentError.new("not a ContentSync message") \
    unless message.is_a?(JEP::Schema::ContentSync)
  return unless message.file
  @content_by_file[message.file] ||= ""
  starti = message.start || 0
  endi = message.end || @content_by_file[message.file].size
  endi = starti if endi < starti
  @content_by_file[message.file][starti, endi-starti] = message.data
  # TODO: check if content really changed
  @listeners.each do |l|
    l.call(message.file)
  end
end

def content(file)
  @content_by_file[file]
end

def add_change_listener(listener)
  @listeners << listener
end

def remove_change_listener(listener)
  @listeners.delete(listener)
end

end

end
