require 'rspec'

class IniFileParser

  ParseError = Struct.new(:line, :line_number, :message)
  Section = Struct.new(:name, :properties)

  attr_reader :errors, :sections
  def self.from_file(file)
    from_string(File.read(file))
  end
  def self.from_string(s)
    IniFileParser.new(s)
  end
  def initialize(content)
    @errors = []
    @sections = {}
    line_number = 1
    content.each_line do |line|
      parse(line.strip, line_number)
      line_number += 1
    end
  end
  COMMENT_PATTERN = /^\#|;/
  START_OF_SECTION_PATTERN = /^\[/
  SECTION_PATTERN = /^\[([^\]]+?)\]$/
  KEY_VALUE_PATTERN = /^\s*([^=]+?)\s*=\s*(.+?)\s*$/
  def parse(line, line_number)
    return if line.match(COMMENT_PATTERN)

    if line.match(START_OF_SECTION_PATTERN)
      section = line.match(SECTION_PATTERN)
      if section
        name = section[1]
        @current_section = Section.new(name, {})
        @sections[name] = @current_section
      else
        @errors << ParseError.new(line, line_number, 'wrong section header')
      end
      return
    end

    key_value = line.match(KEY_VALUE_PATTERN)
    if key_value
      if @current_section
        @current_section.properties[key_value[1]] = key_value[2]
      else
        @errors << ParseError.new(line, line_number, 'key value outside of section')
      end
    end
  end
end





