class SimpleTask
  attr_accessor :id
  attr_accessor :priority
  
  attr_accessor :owner_id
  attr_accessor :job_id
  
  def initialize(owner_id, job_id, id, priority)
    @owner_id = owner_id
    @job_id = job_id
    @id = id
    @priority = priority
  end
end