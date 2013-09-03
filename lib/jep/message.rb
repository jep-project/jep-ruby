module JEP

class Message
attr_reader :object
attr_reader :binary

def initialize( object={}, binary="")
  @object = object
  @binary = binary
  @binary.force_encoding("binary")
end

end

end
