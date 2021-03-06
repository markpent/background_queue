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
      raise "Missing priority" if @priority.nil?
      @worker = worker
      @running = false
      @options = options
      @params = params
    end
    
    def to_json(dummy=true)
      to_json_object(false).to_json
    end
    
    def to_json_object(full)
      jo = {:owner_id=>@owner_id, :job_id=>@job_id, :id=>@id, :priority=>@priority, :worker=>@worker, :params=>@params }
      if full
        jo[:options] = @options
      end
      jo
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
    
    def get_job
      @job
    end
    
    def is_excluded_from_count?
      @options[:exclude] == true
    end
    
    def synchronous?
      @options[:synchronous] == true
    end
    
    def weighted?
      @options[:weight] && @options[:weight] > 0
    end
    
    def weighted_percent
      @options[:weight]
    end
    
    def initial_progress_caption
      @options[:initial_progress_caption]
    end
    
    def send_summary?
      @options[:send_summary] 
    end
    
    def get_error_count
      if @error_count.nil?
        0
      else
        @error_count
      end
    end
    
    def set_error_status(e_status)
      @error_status = e_status
    end
    
    def get_error_status
      @error_status
    end
    
    def waiting_to_retry?
      @error_status == :waiting_to_retry
    end
    
    def replaced_while_waiting_to_retry?
      @error_status == :replaced_while_waiting_to_retry
    end
    
    def increment_error_count
      @error_count = get_error_count + 1
    end
    
    def get_worker_error_count
      if @error_worker_count.nil?
        0
      else
        @error_worker_count
      end
    end
    
    def increment_worker_error_count
      @error_worker_count = get_worker_error_count + 1
    end
    
    def retry_task?
      @options[:retry_limit] && @options[:retry_limit] > get_worker_error_count
    end
    
    def errors_allowed?
      @options[:errors_allowed]
    end   
    
    def set_as_errored
      if @job && !errors_allowed?
        @job.set_as_errored(self)
      end
    end
    
    def step
      @options[:step]
    end
    
    def cancelled?
      @job && @job.cancelled?
    end
    
    
    def set_worker_status(status)
      raise "Task without job set" if @job.nil?
      status[:task_id] = self.id
      status[:exclude] = self.is_excluded_from_count?
      status[:weight] = self.weighted_percent if self.weighted?
      @job.set_worker_status(status)
    end
  end
end
