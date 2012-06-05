module BackgroundQueue::ServerLib
  class Task
    
    attr_accessor :id
    attr_accessor :priority
    
    attr_accessor :owner_id
    attr_accessor :job_id
    
    attr_accessor :worker
    
    attr_accessor :running
    
    attr_accessor :options
  
    def initialize(owner_id, job_id, id, priority, worker, params, options)
      @owner_id = owner_id
      @job_id = job_id
      @id = id
      @priority = priority
      @worker = worker
      @running = false
      @options = options
      @params = params
    end
    
    def running?
      @running
    end
    
    def domain
      @options[:domain]
    end
    
    def set_job(job)
      @job = job
    end
    
    def is_excluded_from_count?
      @options[:exclude] == true
    end
    
    def synchronous?
      @options[:synchronous] == true
    end
    
    def set_worker_status(status)
      raise "Task without job set" if @job.nil?
      status[:task_id] = self.id
      status[:exclude] = self.is_excluded_from_count?
      @job.set_worker_status(status)
    end
  end
end
