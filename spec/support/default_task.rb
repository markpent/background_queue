require File.expand_path(File.dirname(__FILE__) + '/simple_task')
class DefaultTask < SimpleTask

  def initialize
    super(:owner_id, :job_id, :id, :priority)
  end
  
  
end
