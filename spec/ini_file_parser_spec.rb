require_relative '../demo/gitconfig_backend'

describe IniFileParser do
  before do
    @ini_file = IniFileParser.from_file('spec/spec.ini')
  end
  it 'should load from string' do
    ini_file = IniFileParser.from_string('')
    expect(ini_file.errors).to eq([])
  end
  it 'should load from file' do
    expect(@ini_file.errors).to include(IniFileParser::ParseError.new('[section_not_closed', 1, 'wrong section header'))
  end
  it 'should deliver all sections' do
    expect(Set.new(@ini_file.sections.values.map{|s|s.name})).to eq(Set.new(%w(section1 section2 section3)))
  end
  it 'should deliver error on sections with additional ]' do
    expect(@ini_file.errors).to include(IniFileParser::ParseError.new('[section4]]', 2, 'wrong section header'))
  end
  it 'should deliver the section with its key-value-pairs' do
    expect(@ini_file.sections['section1'].properties).to eq({'k1' => 'v5', 'k2' => 'v6'})
    expect(@ini_file.sections['section2'].properties).to eq({'k1' => 'v3', 'k2' => 'v4'})
    expect(@ini_file.sections['section3'].properties).to eq({'k1' => 'v1', 'k2' => 'v2'})
  end
end
