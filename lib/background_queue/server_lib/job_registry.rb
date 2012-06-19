module BackgroundQueue::ServerLib
  #keep track of jobs, even after they have finished.
  #this allows us to query the status of the job after its finished.
  #It is used to get the status of the job
  class JobRegistry
    def initialize(size = 1000)
      @lru = Cache::LRU.new(:max_elements=>size)
      @mutex = Mutex.new
      
    end
  
    def register(job)
      @mutex.synchronize {
        @lru[job.id] = job
      }
    end
    
    def get_job(id)
      @mutex.synchronize {
        @lru[id]
      }
    end
    
    private
    
    def lru
      @lru
    end
  end
end
