require 'json'

module BackgroundQueue

  #store a command and all its parameters as a hash to be serialized when passing to the server.
  class Command
  
    #create an 'add task' command
    def self.add_task_command(worker, owner_id, job_id, task_id, task_parameters={}, options={} )
      Command.new(:add_task, options, :worker=>worker, :owner_id=>owner_id, :job_id=>job_id, :task_id=>task_id, :params=>task_parameters)
    end
    
    #create an 'add tasks' command
    def self.add_tasks_command(worker, owner_id, job_id, tasks, shared_parameters={}, options={} )
      raise InvalidCommand, "No Tasks In List" if tasks.nil? || tasks.length == 0
      Command.new(:add_tasks, options, :worker=>worker, :owner_id=>owner_id, :job_id=>job_id, :tasks=>tasks, :shared_parameters=>shared_parameters)
    end
    
    #create a 'remove tasks' command
    def self.remove_tasks_command(tasks, options={})
      raise InvalidCommand, "No Tasks In List" if tasks.nil? || tasks.length == 0
      Command.new(:remove_tasks, options, {:tasks=>tasks})
    end
    
    
    attr_accessor :code
    attr_accessor :options
    attr_accessor :args
    
    def initialize(code, options, args)
      @code = code
      @options = BackgroundQueue::Utils::AnyKeyHash.new(options)
      @args = BackgroundQueue::Utils::AnyKeyHash.new(args)
    end
    
    #convert the command to a string (currently json) to get sent
    def to_buf
      {:c=>@code, :a=>@args.hash, :o=>@options.hash}.to_json
    end
    
    #load a command from a string
    def self.from_buf(buf)
      hash_data = nil
      begin
        hash_data = JSON.load(buf)
      rescue Exception=>e
        raise InvalidCommand, "Invalid data format (should be json) when loading command from buffer: #{e.message}"
      end
      begin
        raise "Missing 'c' (code)" if hash_data['c'].nil?
        code = hash_data['c'].intern
        raise "Missing 'a' (args)" if hash_data['a'].nil?
        args = hash_data['a']
        raise "Missing 'o' (options)" if hash_data['o'].nil?
        options = hash_data['o']
        BackgroundQueue::Command.new(code, options, args)
      rescue Exception=>e
        raise InvalidCommand, "Error loading command from buffer: #{e.message}"
      end
    end
  end
  
  #Error raised when command is invalid
  class InvalidCommand < Exception
    
  end
end
