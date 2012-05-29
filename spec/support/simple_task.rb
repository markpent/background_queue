class SimpleTask
  attr_accessor :id
  attr_accessor :priority
  
  attr_accessor :owner_id
  attr_accessor :job_id
  
  attr_accessor :running
  
  attr_accessor :options
  
  def initialize(owner_id, job_id, id, priority, options={})
    @owner_id = owner_id
    @job_id = job_id
    @id = id
    @priority = priority
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
end
