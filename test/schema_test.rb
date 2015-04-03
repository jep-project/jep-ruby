$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'jep/schema'

class SchemaTest < Test::Unit::TestCase

def test_message_access_methods
  o = JEP::Schema::ContentSync.new
  o.file = "filename1"
  assert_equal "filename1", o.file
end

def test_struct_access_methods
  o = JEP::Schema::Problem.new
  o.message = "message1"
  assert_equal "message1", o.message
end

def test_enum
  o = JEP::Schema::Problem.new
  o.severity = :debug
  assert_equal :debug, o.severity
  assert_raise do
    o.severity = :dubeg
  end
end

def test_containment
  o = JEP::Schema::FileProblems.new
  o.addProblems(JEP::Schema::Problem.new)
  assert o.problems.first.is_a?(JEP::Schema::Problem)
end

end
