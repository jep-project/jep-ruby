$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'logger'
require 'jep/frontend/connector_manager'

handler = Object.new
class << handler
def handle_OutOfSync(msg)
  puts "** out of sync **"
end
end
man = JEP::Frontend::ConnectorManager.new(handler,
  :logger => Logger.new($stdout),
  :keep_outfile => true)
con = man.connector_for_file("dummy.demo")
con.connect

while true
  print "file: "
  file = gets.strip
  print "content: "
  content = gets.strip
  print "indices: "
  start_i, end_i = gets.strip.split(",").collect{|i| i.strip}

  con.send_message("ContentSync", {"file" => file, "start" => start_i, "end" => end_i}, content)
  sleep(0.5)
  con.resume
end

