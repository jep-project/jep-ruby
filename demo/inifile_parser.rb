class IniFileParser

  ParseError = Struct.new(:line, :line_number, :message, :severity)
  Section = Struct.new(:name, :properties)
  KeyValue = Struct.new(:value, :line_number)

  attr_reader :errors, :sections

  def self.from_file(file)
    from_string(file, File.read(file))
  end
  def self.from_string(file, s)
    IniFileParser.new(file, s)
  end
  def initialize(file, content)
    @file = file
    @errors = []
    @sections = {}

    line_number = 0
    current_section = nil
    last_line = nil
    content.each_line do |line|
      line_number += 1
      last_line = line
      current_section = parse(line.strip, line_number, current_section)
    end
    if last_line[-1] != "\n"
      @errors << ParseError.new(last_line, line_number, 'newline expected at end of file', 'warning')
    end
  end
  COMMENT_PATTERN = /^\#|;/
  START_OF_SECTION_PATTERN = /^\[/
  SECTION_PATTERN = /^\[([^\]]+?)\]$/
  KEY_VALUE_PATTERN = /^\s*([^=]+?)\s*=\s*(.+?)\s*$/
  def parse(line, line_number, current_section)
    return if line.match(COMMENT_PATTERN)

    if line.match(START_OF_SECTION_PATTERN)
      section = line.match(SECTION_PATTERN)
      if section
        name = section[1]
        current_section = Section.new(name, {})
        @sections[name] = current_section
      else
        @errors << ParseError.new(line, line_number, 'wrong section header', "error")
      end
      return current_section
    end

    key_value = line.match(KEY_VALUE_PATTERN)
    if key_value
      key = key_value[1]
      kv = KeyValue.new(key_value[2], line_number)
      if current_section
        current_section.properties[key] = kv
      else
        @errors << ParseError.new(line, line_number, 'key value outside of section', "error")
      end
    end
    return current_section
  end
end

