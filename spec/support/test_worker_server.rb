require 'webrick'

class TestWorkerServer

  
  attr_reader :control_calling
  
  attr_accessor :is_polling_call
  
  def initialize(port, control_calling = false)
    @port = port
    @control_calling = control_calling
    @is_polling_call = false
  end
  
  def start(proc)
    @server = WEBrick::HTTPServer.new(:BindAddress=>"127.0.0.1", :Port => @port, :Logger=>WEBrick::BasicLog.new([], -1000), :AccessLog=>[]) 
    @server.mount "/background_queue", TestWorkerServer::ProcServlet, proc, self
    @mutex = Mutex.new
    @condvar = ConditionVariable.new
    @called = false
    if @control_calling
      @cmutex = Mutex.new
      @ccondvar = ConditionVariable.new
      @ccalled = false
    end
    
    @thread = Thread.new {
      @server.start
    }
  end
  
  
  
  def stop
    @server.shutdown
    Thread.kill(@thread) #brutal.... but quick...
    #@thread.join
  end
  
  def wait_to_be_called
    was_called = false
    @mutex.synchronize {
      unless @called
        @condvar.wait(@mutex, 5)
      end
      was_called = @called
      @called = false
      #puts "called=#{was_called}"
      was_called
    }
  end
  
  def mark_as_called
    @mutex.synchronize {
      @called = true
      @condvar.signal
    }
  end
  
  def can_to_be_called?
    was_called = false
    @cmutex.synchronize {
      unless @ccalled
        @ccondvar.wait(@cmutex, 5)
      end
      was_called = @ccalled
      @ccalled = false
      was_called
    }
  end
  
  def allow_to_be_called
    @cmutex.synchronize {
      @ccalled = true
      @ccondvar.signal
    }
  end
  
  

  class ProcServlet < WEBrick::HTTPServlet::AbstractServlet

    def initialize(server, proc, test_server)
      super(server)
      @proc = proc
      @test_server = test_server
    end

  
    def do_POST(request, response)
      begin
        @test_server.is_polling_call = false
        response.test_server = @test_server
        @test_server.can_to_be_called? if @test_server.control_calling
        @proc.call(TestWorkerServer::Contoller.new(request, response, @test_server))
      rescue Exception=>e
        puts e.message
        puts e.backtrace.join("\n")
      end
    end
  
  end
  
  class Contoller
    
    attr_accessor :request
    attr_accessor :response
    attr_accessor :params
    attr_accessor :test_server
      
    def initialize(request, response, test_server)
      @request = request
      @response = response
      @logger = WEBrick::BasicLog.new("/tmp/bq-controller.log", 5)
      @params = BackgroundQueue::Utils::AnyKeyHash.new(@request.query)
      @test_server = test_server
    end
    
    def headers
      @response.header
    end
    
    def logger
      @logger
    end
    
    def render(opts)
      @response.status = opts[:status] if opts[:status]
      @response.content_type = opts[:type] if opts[:type]
       
       
      if opts[:text].instance_of?(String)
        @response.body = opts[:text]
      elsif opts[:text].instance_of?(Proc)
        @response.chunked = true
        @response.body = opts[:text]
      end
    end
    
    def handle_worker_error(step, ex)
      logger.error("Error during #{step}: #{ex.message}")
    end
    
  end

end

module WEBrick
  class HTTPResponse
    
    attr_accessor :test_server
    
    alias_method :old_send_response, :send_response
    
    def send_response(socket)
      old_send_response(socket)
      socket.extend SocketExtension
      socket.set_test_server(@test_server)
    end
    
    alias_method :old_send_body, :send_body
   
    def send_body(socket)
      if @body.instance_of?(Proc)
        begin
          @body.call(self, ChunkedOutput.new(socket, self))
          _write_data(socket, "0#{CRLF}#{CRLF}")
        rescue Exception=>e
          puts e.message
          puts e.backtrace.join("\n")
        end
      else
        old_send_body(socket)
      end
    end
    
    def send_chunked_data(socket, buf)
      data = ""
      data << format("%x", buf.size) << CRLF
      data << buf << CRLF
      _write_data(socket, data)
      @sent_size += buf.size
    end
  end
end

class ChunkedOutput
  
  def initialize(socket, response)
    @socket = socket
    @response = response
  end
  
  def write(buf)
    @response.send_chunked_data(@socket, buf)
  end
  
  def flush
    @socket.flush
  end
end

module SocketExtension
  
  def set_test_server(ts)
    @test_server = ts
  end
  
  def close
    super
    @test_server.mark_as_called unless @test_server.nil? || @test_server.is_polling_call
  end
end
  
