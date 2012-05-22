#The Background Queue will schedule tasks in the background. Refer to README for more details. 
module BackgroundQueue
  #The main interface to the background queue from the client.
  #this class will look after sending a command to the server, using a failover server if needed.
  class Client
    
    attr_accessor :config
    
    def initialize(path)
      @config = BackgroundQueue::ClientLib::Config.load_file(path)
    end
    
    #add a task to the background
    def add_task(worker, owner_id, job_id, task_id, task_parameters={}, options={} )
      send_command(BackgroundQueue::ClientLib::Command.add_task_command(worker, owner_id, job_id, task_id, task_parameters, options ))
    end
    
    #add multiple tasks to the background, all with the same worker/owner/job
    def add_tasks(worker, owner_id, job_id, tasks, shared_parameters={}, options={} )
      send_command(BackgroundQueue::ClientLib::Command.add_tasks_command(worker, owner_id, job_id, tasks, shared_parameters, options ))
    end
    
    #removed for now
    #remove tasks from the background queue
    #def remove_tasks(tasks, options={})
    #  send_command(BackgroundQueue::ClientLib::Command.remove_tasks_command(tasks, options))
    #end
    
    
    private
    
    def send_command(command)
      begin
        send_command_to_server(command, @config.server)
      rescue BackgroundQueue::ClientLib::ConnectionError=>e
        failures = []
        failures << e.message
        @config.failover.each_with_index do |server, idx| 
          begin
            return send_command_to_server(command, server)
          rescue BackgroundQueue::ClientLib::ConnectionError=>e2
            failures << ", Attempt #{idx + 2}: #{e2.message}"
          end
        end
        raise ClientException, failures.join("")
      end
    end
    
    def send_command_to_server(command, server)
      connection = BackgroundQueue::ClientLib::Connection.new(self, server)
      connection.send_command(command)
    end
  end
  
  
  #Error raised when unable to send command
  class ClientException < Exception
    
  end
end
