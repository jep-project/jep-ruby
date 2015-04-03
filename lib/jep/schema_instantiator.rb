module JEP

# Instantiates schema classes from protocol message hashes.
class SchemaInstantiator 

# Optional logger object
attr_accessor :logger

def instantiate_message(hash)
  class_name = hash["_message"]
  unless class_name
    log "missing _message key"
    return
  end
  begin
    cdef = JEP::Schema.const_defined?(class_name)
  rescue NameError
  end
  unless cdef
    log "unexpected _message type '#{class_name}'"
    return
  end
  instantiate_struct(JEP::Schema.const_get(class_name), hash.reject{|k| k == "_message"})
end

def instantiate_struct(clazz, hash)
  obj = clazz.new
  hash.keys.each do |key|
    f = clazz.ecore.eAllStructuralFeatures.find{|f| f.name == key}
    if f
      obj.setGeneric(key, instantiate_value(f, hash[key]))
    else
      log "unexpected property '#{key}' within '#{clazz.ecore.name}'"
    end
  end
  required_features(clazz).each do |f|
    unless hash.has_key?(f.name)
      log "missing required property '#{f.name}' within '#{clazz.ecore.name}'"
    end
  end
  obj
end

def instantiate_value(f, val)
  if f.eType.is_a?(RGen::ECore::EClass)
    if f.many
      val.collect{|h| instantiate_struct(f.eType.instanceClass, h)}
    else
      instantiate_struct(f.eType.name, val)
    end
  elsif f.eType.is_a?(RGen::ECore::EEnum)
    val.to_sym
  else
    # String, Integer and Boolean are already correct
    val
  end
end

def required_features(clazz)
  clazz.ecore.eAllStructuralFeatures.select{|f| 
    (!f.is_a?(RGen::ECore::EReference) || !f.eOpposite || !f.eOpposite.containment) && 
    f.lowerBound > 0}
end

def log(desc)
  @logger.error(desc) if @logger
end

end

end
