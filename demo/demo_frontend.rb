$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'logger'
require 'jep/frontend/connector_manager'

man = JEP::Frontend::ConnectorManager.new(nil, 
  :logger => Logger.new($stdout),
  :keep_outfile => true)
con = man.connector_for_file("dummy.demo")
con.connect

while true
  print "file: "
  file = gets.strip
  print "content: "
  content = gets.strip

  con.send_message("ContentSync", {"file" => file}, content)
end

