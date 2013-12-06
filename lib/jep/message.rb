module JEP

class Message

attr_reader :type
attr_reader :object
attr_reader :binary

def initialize(type, object={}, binary="")
  @type = type
  @object = object
  @binary = binary
  @binary.force_encoding("binary")
end

end

end
