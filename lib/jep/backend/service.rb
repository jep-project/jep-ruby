require 'socket'
require 'jep/message_serializer'
require 'jep/schema_serializer'
require 'jep/schema_instantiator'

module JEP
module Backend

class Service

  PortRangeStart = 9001
  PortRangeEnd   = 9100

  FlushInterval  = 1

  # Creates an JEP backend service. Options:
  #
  #  :timeout
  #    idle time in seconds after which the service will terminate itelf
  #
  #  :logger
  #    a logger object on which the service will write its logging output
  #
  #  :on_startup:
  #    a Proc which is called right after the service has started up
  #    can be used to output version information
  #
  def initialize(message_handler, options={})
    @message_handler = message_handler
    @timeout = options[:timeout] || 60
    @logger = options[:logger]
    @on_startup = options[:on_startup]
    @server = nil
    @sockets = []
    @request_data = {}
    @last_flush_time = Time.now
    @message_serializer = MessageSerializer.new
  end

  # startup the server, required before +receive+ or +receive_loop+ can be used
  def startup
    @server = create_server 
    puts "JEP service, listening on port #{@server.addr[1]}"
    @on_startup.call if @on_startup
    $stdout.flush
  end

  # polling mode receive
  def receive
    raise "service not started" unless @server
    begin
      sock = @server.accept_nonblock
      sock.sync = true
      @sockets << sock
      log(:info, "accepted connection")
    rescue Errno::EAGAIN, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR, Errno::EWOULDBLOCK
    rescue Exception => e
      log(:warn, "unexpected exception during socket accept: #{e.class}")
    end
    @sockets.dup.each do |sock|
      data = nil
      begin
        data = sock.read_nonblock(100000)
      rescue Errno::EWOULDBLOCK
      rescue IOError, EOFError, Errno::ECONNRESET, Errno::ECONNABORTED
        sock.close
        @request_data[sock] = nil
        @sockets.delete(sock)
      rescue Exception => e
        # catch Exception to make sure we don't crash due to unexpected exceptions
        log(:warn, "unexpected exception during socket read: #{e.class}")
        sock.close
        @request_data[sock] = nil
        @sockets.delete(sock)
      end
      if data
        last_access_time = Time.now
        @request_data[sock] ||= ""
        @request_data[sock].concat(data)
        while msg = @message_serializer.deserialize_message(@request_data[sock])
          message_received(sock, msg)
        end
      end
    end
    if Time.now > @last_flush_time + FlushInterval
      $stdout.flush
      @last_flush_time = Time.now
    end
  end

  # receive loop which runs until stop is called or a timeouts occurs
  def receive_loop
    raise "service not started" unless @server
    last_access_time = Time.now
    @stop_requested = false
    while !@stop_requested
      receive
      IO.select([@server] + @sockets, [], [], 1)
      if Time.now > last_access_time + @timeout
        log(:info, "JEP service, stopping now (timeout)")
        break 
      end
    end
  end

  # stop the receive loop
  def stop
    log(:info, "JEP service, stopping now (stop requested)")
    @stop_requested = true
  end

  # not to be called by the user directly as +sock+ isn't known.
  # call +send_message+ on the invocation context passed to the reception handler
  def send_message(msg, sock)
    begin
      msg_hash = SchemaSerializer.new.serialize_message(msg)
      sock.write(@message_serializer.serialize_message(msg_hash))
      sock.flush
      # TODO: truncate large messages before logging
      log(:debug, "sent: "+msg_hash.inspect)
    # if there is an exception, the next read should shutdown the connection properly
    rescue IOError, EOFError, Errno::ECONNRESET, Errno::ECONNABORTED
    rescue Exception => e
      # catch Exception to make sure we don't crash due to unexpected exceptions
      log(:warn, "unexpected exception during socket write: #{e.class}")
    end
  end

  private

  def create_server
    port = PortRangeStart
    serv = nil
    begin
      serv = TCPServer.new("127.0.0.1", port)
    rescue Errno::EADDRINUSE, Errno::EAFNOSUPPORT, Errno::EACCES
      port += 1
      retry if port <= PortRangeEnd
      raise
    end
    serv
  end

  class InvocationContext
    def initialize(service, socket)
      @service = service
      @socket = socket
    end
    def send_message(msg)
      @service.send_message(msg, @socket)
    end
    def stop_service
      @service.stop
    end
    def log(severity, message)
      @service.log(severity, message)
    end
  end

  def message_received(sock, msg)
    reception_start = Time.now
    # TODO: truncate large messages before logging
    log(:debug, "received: "+msg.inspect)
    @message_handler.message_received(
      SchemaInstantiator.new.instantiate_message(msg),
      InvocationContext.new(self, sock))
    log(:info, "reception complete (#{Time.now-reception_start}s)")
  end

  def log(severity, message)
    if @logger
      @logger.send(severity, message)
    end
  end

end

end
end

