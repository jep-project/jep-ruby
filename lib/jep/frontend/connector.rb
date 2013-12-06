require 'socket'
require 'jep/message_helper'
require 'win32/process' if RUBY_PLATFORM =~ /mingw/

module JEP
module Frontend

class Connector
include JEP::MessageHelper

attr_reader :config

def initialize(config, options={})
  @config = config
  @logger = options[:logger]
  @state = :off
  @message_handler = options[:message_handler]
  @connection_listener = options[:connect_callback]
  @connection_timeout = options[:connection_timeout] || 10
  @log_service_output = options[:log_service_output]
  @service_output = ""
end

def send_message(type, object={}, binary="")
  if connected?
    msg = JEP::Message.new(type, object, binary)
    @logger.debug("sent: #{msg.inspect}") if @logger
    @socket.send(serialize_message(msg), 0)
    :success
  else
    :not_connected
  end
end

def resume
  do_work
  if @log_service_output
    service_output_lines.each do |l|
      @logger.info("SVC>: #{l}")
    end
  end
end

def stop
  if connected?
    send_message("Stop")
    :success
  else
    :not_connected
  end
end

def connected?
  @state == :connected && backend_running?
end

def connect
  return if connected?
  connect_internal unless connecting?
  i = 0
  while !connected? && i<50
    do_work
    sleep(0.1)
    i += 1
  end
  if i == 50
    :timeout
  else
    :success
  end
end

def read_service_output_lines
  read_service_output
  service_output_lines
end

private

def service_output_lines
  lines = @service_output.split("\n")
  if @service_output[-1] == "\n"
    @service_output = ""
    lines
  else
    @service_output = lines[-1] || ""
    lines[0..-2]
  end
end

def connecting?
  @state == :connecting
end

def connect_internal
  @state = :connecting
  @connect_start_time = Time.now

  @logger.info "starting: #{@config.command}" if @logger

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

  @work_state = :wait_for_port
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

def do_work
  read_service_output
  case @work_state
  when :wait_for_port
    if @service_output =~ /^JEP service, listening on port (\d+)/
      port = $1.to_i
      @logger.info "connecting to #{port}" if @logger
      begin
        @socket = TCPSocket.new("127.0.0.1", port)
        @socket.setsockopt(:SOCKET, :RCVBUF, 1000000)
        @state = :connected
        @work_state = :read_from_socket
        @connection_listener.call(:connected) if @connection_listener
        @logger.info "connected" if @logger
      rescue Errno::ECONNREFUSED
        cleanup
        @connection_listener.call(:timeout) if @connection_listener
        @work_state = :done
        @state = :off
        @logger.warn "could not connect socket (connection refused)" if @logger
      end
    end
    if Time.now > @connect_start_time + @connection_timeout
      cleanup
      @connection_listener.call(:timeout) if @connection_listener
      @work_state = :done
      @state = :off
      @logger.warn "could not connect socket (connection timeout)" if @logger
    end
    true
  when :read_from_socket
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
        @logger.info "server socket closed (end of file)" if @logger
      end
      if data
        repeat = true
        response_data.concat(data)
        while msg = extract_message(response_data)
          message_received(msg)
        end
      elsif !backend_running? || socket_closed
        cleanup
        @work_state = :done
        return false
      end
    end
    true
  end

end

def message_received(msg)
  reception_start = Time.now
  @logger.debug("received: "+msg.inspect) if @logger
  message_type = msg.type
  if message_type
    handler_method = "handle_#{message_type}".to_sym
    if @message_handler.respond_to?(handler_method)
      @message_handler.send(handler_method, msg)
    else
      @logger.warn("can not handle message #{message_type}") if @logger
    end
  else
    @logger.warn("invalid message (no '_message' property)") if @logger
  end
  @logger.info("reception complete (#{Time.now-reception_start}s)") if @logger
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
end

def cleanup
  @socket.close if @socket
end

end

end
end


