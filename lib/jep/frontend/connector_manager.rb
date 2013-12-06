require 'digest'
require 'jep/config'
require 'jep/frontend/connector'

module JEP
module Frontend

# A ConnectorManager decides when to create new connectors.
# When a config file changes, all affected connectors are restarted on the next request.
#
class ConnectorManager

def initialize(&connector_provider)
  @connector_provider = connector_provider
  @connector_descs = {}
end

ConnectorDesc = Struct.new(:connector, :checksum)

def connector_for_file(file)
  config = Config.find_service_config(file)
  if config
    key = desc_key(config)
    desc = @connector_descs[key]
    if desc
      if desc.checksum == config_checksum(config)
        desc.connector
      else
        # connector must be replaced
        desc.connector.stop
        create_connector(config) 
      end
    else
      create_connector(config)
    end
  else
    nil
  end
end

def all_connectors
  @connector_descs.values.collect{|v| v.connector}
end

private

def create_connector(config)
  con = @connector_provider.call(config)
  desc = ConnectorDesc.new(con, config_checksum(config))
  key = desc_key(config)
  @connector_descs[key] = desc
  desc.connector
end

def desc_key(config)
  config.file.downcase + "," + config.patterns.join(",")
end

def config_checksum(config)
  if File.exist?(config.file)
    sha1 = Digest::SHA1.new
    sha1.file(config.file)
    sha1.hexdigest
  else
    nil
  end
end


end

end
end

