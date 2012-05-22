require 'json'

module BackgroundQueue::ClientLib

  #store a command and all its parameters as a hash to be serialized when passing to the server.
  module Command
  
    #create an 'add task' command
    def self.add_task_command(worker, owner_id, job_id, task_id, priority, task_parameters={}, options={} )
      BackgroundQueue::Command.new(:add_task, options, :worker=>worker, :owner_id=>owner_id, :job_id=>job_id, :task_id=>task_id, :priority=>priority, :params=>task_parameters)
    end
    
    #create an 'add tasks' command
    def self.add_tasks_command(worker, owner_id, job_id, tasks, priority, shared_parameters={}, options={} )
      raise BackgroundQueue::InvalidCommand, "No Tasks In List" if tasks.nil? || tasks.length == 0
      BackgroundQueue::Command.new(:add_tasks, options, :worker=>worker, :owner_id=>owner_id, :job_id=>job_id, :tasks=>tasks, :priority=>priority, :shared_parameters=>shared_parameters)
    end
    
    #create a 'remove tasks' command
    #is this needed?
    #def self.remove_tasks_command(tasks, options={})
    #  raise BackgroundQueue::InvalidCommand, "No Tasks In List" if tasks.nil? || tasks.length == 0
    #  BackgroundQueue::Command.new(:remove_tasks, options, {:tasks=>tasks})
    #end
  end
end
