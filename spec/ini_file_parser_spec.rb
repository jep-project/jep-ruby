require_relative '../demo/inifile_parser'

describe IniFileParser do
  before do
    @ini_file = IniFileParser.from_file('spec/spec.ini')
  end
  it 'should load from file' do
    expect(@ini_file.errors).to include(IniFileParser::ParseError.new('[section_not_closed', 1, 'wrong section header', 'error'))
    expect(@ini_file.errors).to include(IniFileParser::ParseError.new('[section4]]', 2, 'wrong section header', 'error'))
    expect(@ini_file.errors).to include(IniFileParser::ParseError.new('# hash comment', 13, 'newline expected at end of file', 'warning'))
    expect(@ini_file.errors.length).to eq(3)
  end
  it 'should deliver all sections' do
    expect(Set.new(@ini_file.sections.values.map{|s|s.name})).to eq(Set.new(%w(section1 section2 section3)))
  end
  it 'should deliver error on sections with additional ]' do
    expect(@ini_file.errors).to include(IniFileParser::ParseError.new('[section4]]', 2, 'wrong section header', 'error'))
  end
  it 'should deliver the section with its key-value-pairs' do
    expect(@ini_file.sections['section1'].properties).to eq({'k1' => IniFileParser::KeyValue.new('v5', 10),
                                                             'k2' => IniFileParser::KeyValue.new('v6', 11)})
    expect(@ini_file.sections['section2'].properties).to eq({'k1' => IniFileParser::KeyValue.new('v3', 7),
                                                             'k2' => IniFileParser::KeyValue.new('v4', 8)})
    expect(@ini_file.sections['section3'].properties).to eq({'k1' => IniFileParser::KeyValue.new('v1', 4),
                                                             'k2' => IniFileParser::KeyValue.new('v2', 5)})
  end
end
