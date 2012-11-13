class SimpleTask
  attr_accessor :id
  attr_accessor :priority
  
  attr_accessor :owner_id
  attr_accessor :job_id
  attr_accessor :worker
  
  attr_accessor :running
  
  attr_accessor :options
  
  def initialize(owner_id, job_id, id, priority, options={})
    @owner_id = owner_id
    @job_id = job_id
    @id = id
    @priority = priority
    @worker = :worker
    @running = false
    @options = options
  end
  
  def running?
    @running
  end
  
  def synchronous?
    @options[:synchronous] == true
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
  
  def weighted?
    @options[:percent] && @options[:percent] > 0
  end
  
  def weighted_percent
    @options[:percent]
  end
  
  def initial_progress_caption
    @options[:initial_progress_caption]
  end
  
  def send_summary?
    @options[:send_summary]
  end
  
  def step
    @options[:step]
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
end
