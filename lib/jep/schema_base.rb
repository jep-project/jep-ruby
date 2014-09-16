require 'rgen/metamodel_builder'

module JEP

module Schema
extend RGen::MetamodelBuilder::ModuleExtension

Boolean = RGen::MetamodelBuilder::DataTypes::Boolean

class Struct < RGen::MetamodelBuilder::MMBase

def self.prop(name, *args)
  if args[0].is_a?(Array)
    mult = args[0]
    type = args[1]
  else
    # default multiplicity
    mult = [1, 1]
    type = args[0]
  end
  attrs = {}
  if mult[0].is_a?(Integer)
    attrs[:lowerBound] = mult[0]
  else
    raise "unexpected lower bound"
  end
  if type.respond_to?(:ecore)
    if mult[1] == :*
      contains_many_uni name, type, attrs
    else
      contains_one name, type, attrs
    end
  else
    if mult[1] == :*
      has_many_attr name, type, attrs
    else
      has_attr name, type, attrs
    end
  end
end

end

class Message < Struct

def self.binary
  has_attr "binary", String do
    annotation :source => "jep", :details => {"binary" => "true"}
  end
end

end

def self.message(name, &block)
  const_set(name.to_sym, Class.new(Message, &block))
end

def self.struct(name, &block)
  const_set(name.to_sym, Class.new(Struct, &block))
end

def self.enum(name, literals)
  const_set(name.to_sym, RGen::MetamodelBuilder::DataTypes::Enum.new(:name => name, :literals => literals))
end

end

end
