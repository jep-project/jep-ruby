$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'jep/schema'
require 'jep/schema_instantiator'

class SchemaInstantiatorTest < Test::Unit::TestCase

def setup
  @inst = JEP::SchemaInstantiator.new
end

def test_string
  m = @inst.instantiate_message(
    {"_message"=>"ContentSync", "file"=>"filename1"}
  )
  assert m.is_a?(JEP::Schema::ContentSync)
  assert_equal "filename1", m.file
end

def test_integer
  m = @inst.instantiate_message(
    {"_message"=>"ContentSync", "start"=>5}
  )
  assert m.is_a?(JEP::Schema::ContentSync)
  assert_equal 5, m.start
end

def test_enum
  m = @inst.instantiate_message(
    {"_message"=>"ProblemUpdate",
      "fileProblems"=> [
        {"problems"=>[
          {"severity"=>"warn"}]}]}
  )
  assert m.fileProblems[0].problems[0].is_a?(JEP::Schema::Problem)
  assert_equal :warn, m.fileProblems[0].problems[0].severity
end

def test_nested
  m = @inst.instantiate_message(
    {"_message"=>"ProblemUpdate",
      "fileProblems"=> [
        {"file"=>"file1",
         "problems"=>[
          {"message"=>"prob1"}, 
          {"message"=>"prob2"}]}]}
  )
  assert m.is_a?(JEP::Schema::ProblemUpdate)
  assert_equal 1, m.fileProblems.size
  assert m.fileProblems[0].is_a?(JEP::Schema::FileProblems)
  assert_equal 2, m.fileProblems[0].problems.size
  assert m.fileProblems[0].problems[0].is_a?(JEP::Schema::Problem)
  assert m.fileProblems[0].problems[1].is_a?(JEP::Schema::Problem)
  assert_equal "prob1", m.fileProblems[0].problems[0].message
  assert_equal "prob2", m.fileProblems[0].problems[1].message
end

def test_unexpected_property
  @inst.logger = mock_logger
  m = @inst.instantiate_message(
    {"_message"=>"ContentSync", "stort"=>5}
  )
  assert @inst.logger.errors.any?{|e| e =~ /unexpected property 'stort'/}
end


def test_missing_property
  @inst.logger = mock_logger
  m = @inst.instantiate_message(
    {"_message"=>"ContentSync"}
  )
  assert @inst.logger.errors.any?{|e| e =~ /missing required property 'file'/}
end

def test_missing_message_property
  @inst.logger = mock_logger
  m = @inst.instantiate_message(
    {}
  )
  assert @inst.logger.errors.any?{|e| e =~ /missing _message key/}
end

def test_unexpected_message_type
  @inst.logger = mock_logger
  m = @inst.instantiate_message(
    {"_message" => "bla"}
  )
  assert @inst.logger.errors.any?{|e| e =~ /unexpected _message type/}
end

def mock_logger
  logger = Object.new
  class << logger
    attr_reader :errors
    def error(desc)
      (@errors ||= []) << desc
    end
  end
  logger
end

end

