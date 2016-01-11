module JEP

module Config

def self.find_service_config(file)
  last_dir = nil
  dir = File.expand_path(File.dirname(file))
  search_patterns = file_pattern(file)
  while dir != last_dir
    config_file = "#{dir}/.jep"
    if File.exist?(config_file)
      configs = parse_config_file(config_file)
      config = configs.find{|s| s.patterns.any?{|p| search_patterns.include?(p)}}
      return config if config
    end
    last_dir = dir
    dir = File.dirname(dir)
  end
  nil
end

def self.file_pattern(file)
  ext = File.extname(file)
  if ext.size > 0
    ["*#{ext}", File.basename(file)]
  else
    [File.basename(file)]
  end
end

ServiceConfig = Struct.new(:file, :patterns, :command)
 
def self.parse_config_file(file)
  configs = []
  File.open(file) do |f|
    lines = f.readlines
    l = lines.shift
    while l
      if l =~ /^(.+):\s*$/
        patterns = $1.split(",").collect{|s| s.strip} 
        l = lines.shift
        if l && l =~ /\S/ && l !~ /:\s*$/
          configs << ServiceConfig.new(file, patterns, l)
          l = lines.shift
        end
      else
        l = lines.shift
      end
    end
  end
  configs
end

end

end
