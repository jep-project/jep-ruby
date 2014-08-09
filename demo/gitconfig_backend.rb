$:.unshift(File.dirname(__FILE__)+"/../lib")
require 'logger'
require 'jep/backend/service'
require 'jep/backend/message_handler'
require 'parser/current'
require_relative 'inifile_parser'

class GitConfig
  EMAIL_PATTERN = /.+@.+/

  def self.search_in(working_dir, file_name, content)
    configs = [IniFileParser.from_string(file_name, content)]
    configs = collect_configs(configs, File.absolute_path(File.join(working_dir, '..')))
    configs.each do |config|
      user_section = config.sections['user']
      if user_section
        email = user_section.properties['email']
        if email
          if !email.value.match(EMAIL_PATTERN)#TODO use real line of key_value
            config.errors << IniFileParser::ParseError.new("test", email.line_number, "user email seems fishy '#{email.value}'", "warning")
          end
        end
      end
    end
  end

  def self.collect_configs(configs, dir)
    config_name = File.absolute_path(File.join(dir, '.gitconfig'))
    if File.exist?(config_name)
      puts "found #{config_name}"
      configs << IniFileParser.from_file(config_name)
    end
    parent = File.absolute_path(File.join(dir, '..'))
    configs = collect_configs(configs, parent) unless parent == "/"
    configs
  end
end

handler = JEP::Backend::MessageHandler.new(
  :content_checker => proc do |file, content|
    GitConfig.search_in('.', file, content).
      map{|c|c.errors}.
      flatten.
      map do |parse_error|
      {
        :message => parse_error.message,
        :line => parse_error.line_number.to_i,
        :severity => parse_error.severity
      }
    end
  end
)

service = JEP::Backend::Service.new(handler, :logger => Logger.new($stdout), :timeout => 3600)
service.startup
service.receive_loop
