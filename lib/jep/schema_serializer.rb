module JEP

# Serialize instances of schema classes to protocol message hashes.
class SchemaSerializer

# Optional logger object
attr_accessor :logger

def serialize_message(message)
  hash = serialize_struct(message)
  hash["_message"] = message.class.ecore.name
  hash
end

def serialize_struct(struct)
  hash = {}
  struct.class.ecore.eAllStructuralFeatures.each do |f|
    # ignore parent refs
    next if f.eOpposite && f.eOpposite.containment
    val = struct.getGeneric(f.name)
    if val.is_a?(Array)
      if !val.empty?
        hash[f.name] = val.collect{|v| serialize_value(f, v)}
      end
    else
      if !val.nil?
        hash[f.name] = serialize_value(f, val)
      end
    end
  end
  hash
end

def serialize_value(f, val)
  if f.eType.is_a?(RGen::ECore::EClass)
    serialize_struct(val)
  elsif f.eType.is_a?(RGen::ECore::EEnum)
    val.to_str
  else
    # String, Integer and Boolean are already correct
    val
  end
end

end

end
