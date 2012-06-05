#make sure threads are schedules and the max number of threads is controlled
class BackgroundQueue::ServerLib::ThreadManager

  attr_accessor :max_threads
  attr_reader :running_threads
  
  def initialize(server, max_threads)
    @server
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
      if @running_threads >= @max_threads
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
    @running_threads -= 1
    @condvar.wait(@mutex)
    @running_threads += 1
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
        @threads << Thread.new {
          runner.run
        }
      end
    }
  end
  
  def wait
    for thread in @threads
      thread.join
      @running_threads -= 1
    end
  end
end
