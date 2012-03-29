module BackgroundQueue

  #store a command and all its parameters as a hash to be serialized when passing to the server.
  class Command
  
    def self.add_task_command(worker, owner_id, job_id, task_id, task_parameters={}, options={} )
      Command.new(:add_task, options, :worker=>worker, :owner_id=>owner_id, :job_id=>job_id, :task_id=>task_id, :params=>task_parameters)
    end
    
    def self.add_tasks_command(worker, owner_id, job_id, tasks, shared_parameters={}, options={} )
      raise InvalidCommand, "No Tasks In List" if tasks.nil? || tasks.length == 0
      Command.new(:add_tasks, options, :worker=>worker, :owner_id=>owner_id, :job_id=>job_id, :tasks=>tasks, :shared_parameters=>shared_parameters)
    end
    
    def self.remove_tasks_command(tasks, options={})
      raise InvalidCommand, "No Tasks In List" if tasks.nil? || tasks.length == 0
      Command.new(:remove_tasks, options, {:tasks=>tasks})
    end
    
    attr_accessor :options
    attr_accessor :args
    attr_accessor :code
    
    def initialize(code, options, args)
      @code = code
      @args = args
      @options = options
    end
    
  end
  
  class InvalidCommand < Exception
    
  end
end
