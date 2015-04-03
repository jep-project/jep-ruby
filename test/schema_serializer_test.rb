$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'jep/schema'
require 'jep/schema_serializer'

class SchemaSerializerTest < Test::Unit::TestCase

def setup
  @ser = JEP::SchemaSerializer.new
end

def test_string
  m = JEP::Schema::ContentSync.new
  m.file = "filename1"
  assert_equal(
    {"_message"=>"ContentSync", "file"=>"filename1"},
    @ser.serialize_message(m))
end

def test_integer
  m = JEP::Schema::ContentSync.new(:start => 5)
  assert_equal(
    {"_message"=>"ContentSync", "start"=>5},
    @ser.serialize_message(m))
end

def test_enum
  m = JEP::Schema::ProblemUpdate.new(
        :fileProblems => [
          JEP::Schema::FileProblems.new(
            :problems => [
              JEP::Schema::Problem.new(:severity => :warn) ]) ])
  assert_equal(
    {"_message"=>"ProblemUpdate",
      "fileProblems"=> [
        {"problems"=>[
          {"severity"=>"warn"}]}]},
    @ser.serialize_message(m))
end

def test_nested
  m = JEP::Schema::ProblemUpdate.new(
        :fileProblems => [
          JEP::Schema::FileProblems.new(
            :file => "file1",
            :problems => [
              JEP::Schema::Problem.new(:message => "prob1"),
              JEP::Schema::Problem.new(:message => "prob2") ]) ])
  assert_equal(
    {"_message"=>"ProblemUpdate",
      "fileProblems"=> [
        {"file"=>"file1",
         "problems"=>[
          {"message"=>"prob1"}, 
          {"message"=>"prob2"}]}]},
    @ser.serialize_message(m))
end

def test_fail_on_struct
  m = JEP::Schema::Problem.new
  assert_raise do
    @ser.serialize_message(m)
  end
end

end
