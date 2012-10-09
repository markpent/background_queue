#make sure threads are schedules and the max number of threads is controlled
class BackgroundQueue::ServerLib::ThreadManager

  attr_accessor :max_threads
  attr_reader :running_threads
  
  def initialize(server, max_threads)
    @server = server
    @max_threads = max_threads
    @running_threads = 0
    @mutex = Mutex.new
    @condvar = ConditionVariable.new
    @threads = []
  end
  
  def protect_access(&block)
    @mutex.synchronize {
      block.call
    }
  end

  def control_access(&block)
    @mutex.synchronize {
      if @running_threads >= @max_threads && @server.running?
        @running_threads -= 1
        @condvar.wait(@mutex)
        @running_threads += 1
      end
      block.call
    }
  end
  
  #signal any waiting threads
  #this should only be called from with a protect_access/control_access block
  #will do nothing if there are already too many threads running
  def signal_access
    @condvar.signal unless @running_threads >= @max_threads
  end
  
  #wait for the condition
  #must be called from within protect_access/control_access block
  def wait_on_access
    if @server.running?
      @running_threads -= 1
      #puts "waiting"
      @condvar.wait(@mutex)
      #puts "woken"
      @running_threads += 1
    end
  end
  
  def change_concurrency(max_threads)
    @mutex.synchronize {
      if max_threads > @max_threads
        for i in @max_threads...max_threads
          @condvar.signal
        end
      end
      @max_threads = max_threads
    }
  end
  
  
  def start(clazz)
    @mutex.synchronize {
      for i in 0...@max_threads
        runner = clazz.new(@server)
        @running_threads += 1
        #puts "started thread, running=#{@running_threads}"
        @threads << Thread.new(runner) { |runner|
          begin
            runner.run
          rescue Exception=>e
            @server.logger.error("Error in thread: #{e.message}")
            @server.logger.debug(e.backtrace.join("\n"))
          end
          @mutex.synchronize {
            @running_threads -= 1
            #puts "finished thread, running=#{@running_threads}"
          }
        }
      end
    }
  end
  
  def wait(timeout_limit = 100)
    #for thread in @threads
      @mutex.synchronize {
        @condvar.broadcast
      }
    #end
    #while @running_threads > 0
    #  @mutex.synchronize {
    #    @condvar.signal
    #  }
    #  sleep(0.01)
    #end
    begin
      Timeout::timeout(timeout_limit) {
        for thread in @threads
          thread.join
        end
      }
    rescue Timeout::Error => te
      for thread in @threads
        begin
          if thread.alive?
            thread.raise BackgroundQueue::ServerLib::ThreadManager::ForcedStop.new("Timeout when forcing threads to stop")
          end
        rescue Exception=>e
          #ignore
        end
      end
    end
  end
  
  #Error raised when unable to load configuration
  class ForcedStop < Exception

  end
end
