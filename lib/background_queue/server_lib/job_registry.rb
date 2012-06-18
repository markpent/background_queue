module BackgroundQueue::ServerLib
  #keep track of jobs, even after they have finished.
  #this allows us to query the status of the job after its finished.
  #It is used to get the status of the job
  class JobRegistry
    def initialize
      @lru = Cache::LRU.new(:max_elements=>1000)
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
  end
end
