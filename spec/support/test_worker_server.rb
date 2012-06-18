require 'webrick'

class TestWorkerServer

  def initialize(port)
    @port = port  
  end
  
  def start(proc)
    @server = WEBrick::HTTPServer.new(:BindAddress=>"127.0.0.1", :Port => @port, :Logger=>WEBrick::BasicLog.new([], -1000), :AccessLog=>[]) 
    @server.mount "/background_queue", TestWorkerServer::ProcServlet, proc, self
    @mutex = Mutex.new
    @condvar = ConditionVariable.new
    @called = false
    
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
    @mutex.synchronize {
      unless @called
        @condvar.wait(@mutex, 5)
      end
      @called
    }
  end
  
  def mark_as_called
    @mutex.synchronize {
      @called = true
      @condvar.signal
    }
  end
  
  

  class ProcServlet < WEBrick::HTTPServlet::AbstractServlet

    def initialize(server, proc, test_server)
      super(server)
      @proc = proc
      @test_server = test_server
    end

  
    def do_POST(request, response)
      @proc.call(request, response)
      @test_server.mark_as_called
    end
  
  end

end
