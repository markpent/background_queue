module BackgroundQueue::ClientLib
  #returned from add_task to describe what the job/server was added.
  #this is becuase you can call add_task without a job_id, and not know what server was used.
  #this is passed to get_status
  class JobHandle
    
    attr_reader :owner_id
    attr_reader :job_id
    attr_reader :server
    
    def initialize(owner_id, job_id, server)
      @owner_id = owner_id
      @job_id = job_id
      @server = server
    end
  
  end

end
