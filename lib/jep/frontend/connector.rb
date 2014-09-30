require 'socket'
require 'jep/message_serializer'
require 'jep/schema_instantiator'
require 'jep/schema_serializer'
require 'win32/process' if RUBY_PLATFORM =~ /mingw/

module JEP
module Frontend

# Connector states: [init, connecting, connected, disconnected]

class Connector
attr_reader :config
attr_reader :message_handler

def initialize(config, options={})
  @config = config
  @logger = options[:logger]
  @message_handler = options[:message_handler]
  @connection_listener = options[:connect_callback]
  @connection_timeout = options[:connection_timeout] || 10
  @log_service_output = options[:log_service_output]
  @message_serializer = MessageSerializer.new
  @state = :init
end

def start
  if @state == :init
    start_internal 
    :success
  else
    :not_stopped
  end
end

def stop(options={})
  if @state != :init
    wait_time = options[:wait] || 5
    log :info, "stopping"
    if connected?
      # try to stop backend gracefully
      send_message(Schema::Shutdown.new)
      work :for => wait_time, :while => ->{ backend_running? }
    end
    if backend_running?
      log :info, "backend still running, killing it"
      # still running, do it the hard way
      kill_backend
    end
    @state = :init
    :success
  else
    :not_started
  end
end

def connected?
  @state == :connected
end

def backend_running?
  if @process_id
    if RUBY_PLATFORM =~ /mingw/
      Process.get_exitcode(@process_id) == nil
    else 
      begin
        return true unless Process.waitpid(@process_id, Process::WNOHANG)
      rescue Errno::ECHILD
      end
    end
  else
    false
  end
end

def send_message(msg)
  if connected?
    msg_hash = SchemaSerializer.new.serialize_message(msg)
    @socket.send(@message_serializer.serialize_message(msg_hash), 0)
    log :debug, "sent: #{msg_hash.inspect}"
    :success
  else
    :not_connected
  end
end

# read all complete service output lines
def read_service_output_lines
  read_service_output
  res = @service_output_lines
  @service_output_lines = []
  res
end

# if :for is given, work for the specified amount of seconds
# if :while is given as well, work only while proc returns true
def work(options={})
  for_time = options[:for]
  while_proc = options[:while]
  if for_time
    (1..for_time*10).each do
      work
      break if while_proc && !while_proc.call
      sleep(0.1)
    end
  else
    work_internal
  end
end

def log(level, msg)
  @logger.send(level, msg) if @logger
end

private

def start_internal
  @state = :connecting
  @service_output = ""
  @service_output_lines = []
  @connect_start_time = Time.now

  log :info, "starting: #{@config.command}"

  @service_output_pipe_read, output_pipe_write = IO.pipe

  if RUBY_PLATFORM =~ /mingw/
    @process_id = Process.create(
      :command_line => @config.command.strip,
      :startup_info => {
        :stdout => output_pipe_write,
        :stderr => output_pipe_write
      },
      :creation_flags   => Process::DETACHED_PROCESS,
      :cwd => File.dirname(@config.file)
    ).process_id
  else
    @process_id = Process.spawn(
      @config.command.strip,
      :chdir => File.dirname(@config.file),
      :out => output_pipe_write,
      :err => output_pipe_write
    )
  end
  nil
end

def kill_backend
  if @process_id
    # same for win and non-win platforms
    Process.kill(9, @process_id)
  end
end

def work_internal
  read_service_output
  case @state
  when :connecting
    if @service_output_lines.size > 0 && 
        @service_output_lines[0] =~ /^JEP service, listening on port (\d+)/
      port = $1.to_i
      log :info, "connecting to #{port}"
      begin
        @socket = TCPSocket.new("127.0.0.1", port)
        @socket.setsockopt(:SOCKET, :RCVBUF, 1000000)
        @state = :connected
        @connection_listener.call(:connected) if @connection_listener
        log :info, "connected"
      rescue Errno::ECONNREFUSED
        @socket.close if @socket
        @state = :disconnected
        log :warn, "could not connect socket (connection refused)"
      end
    end
    if Time.now > @connect_start_time + @connection_timeout
      @state = :disconnected
      log :warn, "could not connect socket (connection timeout)"
    end
  when :connected
    repeat = true
    socket_closed = false
    response_data = ""
    while repeat
      repeat = false
      data = nil
      begin
        data = @socket.read_nonblock(1000000)
      rescue Errno::EWOULDBLOCK
      rescue IOError, EOFError, Errno::ECONNRESET
        socket_closed = true
        log :info, "server socket closed (end of file)"
      end
      if data
        repeat = true
        response_data.concat(data)
        while msg = @message_serializer.deserialize_message(response_data)
          message_received(msg)
        end
      elsif socket_closed
        @socket.close
        @state = :disconnected
      end
    end
  end
end

def message_received(msg)
  reception_start = Time.now
  log :debug, "received: "+msg.inspect
  @message_handler.message_received(
    SchemaInstantiator.new.instantiate_message(msg)) if @message_handler
  log :info, "reception complete (#{Time.now-reception_start}s)"
end

def read_service_output
  # using IO.select with timeout 0 and read_partial simulates a read_nonblock
  # which is not available on windows ("bad file handle")
  res = IO.select([@service_output_pipe_read], [], [], 0)
  while res
    begin
      @service_output.concat(@service_output_pipe_read.readpartial(1000))
      res = IO.select([@service_output_pipe_read], [], [], 0)
    rescue EOFError
      res = false
    end
  end
  completed_lines = extract_completed_service_output_lines
  if @log_service_output
    completed_lines.each do |l|
      log :info, "SVC>>>: #{l}"
    end
  end
  @service_output_lines.concat(completed_lines)
  # prevent output lines list from growing too large
  if @service_output.size > 20000
    @service_output_lines.shift(10000)
  end
end

# removes and returns all completed lines from service output
# where a line is completed after a \n
def extract_completed_service_output_lines
  lines = @service_output.split("\n")
  if @service_output[-1] == "\n"
    @service_output = ""
    lines
  else
    @service_output = lines[-1] || ""
    lines[0..-2]
  end
end

end

end
end


