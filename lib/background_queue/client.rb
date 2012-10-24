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
    def add_task(worker, owner_id, job_id, task_id, priority, task_parameters={}, options={}, server=nil )
      job_id, task_id = generate_ids(worker, owner_id, job_id, task_id)
      result, server = send_command(BackgroundQueue::ClientLib::Command.add_task_command(worker, owner_id, job_id, task_id, priority, task_parameters, options ), server)
      #the server currently either returns :ok or an exception would have been thrown
      BackgroundQueue::ClientLib::JobHandle.new(owner_id, job_id, server)
    end
    
    #add multiple tasks to the background, all with the same worker/owner/job
    #tasks is an array in the format [[:task_id1, {:some=>"params"}],[:task_id2, {:some_other=>"params"}, {:some=>"options}]]
    def add_tasks(worker, owner_id, job_id, tasks, priority, shared_parameters={}, options={}, server=nil )
      result, server = send_command(BackgroundQueue::ClientLib::Command.add_tasks_command(worker, owner_id, job_id, tasks, priority, shared_parameters, options ), server)
      #the server currently either returns :ok or an exception would have been thrown
      BackgroundQueue::ClientLib::JobHandle.new(owner_id, job_id, server)
    end
    
    def get_status(job_handle, options={})
      result, server = send_command(BackgroundQueue::ClientLib::Command.get_status_command(job_handle.job_id, options ), job_handle.server)
      result
    end
    
    def get_stats(server, options={})
      result, server = send_command(BackgroundQueue::ClientLib::Command.stats_command(options ), server)
      result.args
    end
    
    
    #removed for now
    #remove tasks from the background queue
    #def remove_tasks(tasks, options={})
    #  send_command(BackgroundQueue::ClientLib::Command.remove_tasks_command(tasks, options))
    #end
    
    
    private
    
    #generate what should be a unique id for a job/task
    def generate_ids(worker, owner_id, job_id, task_id)
      if job_id.nil?
        job_id = "#{worker}-#{get_node_name}-#{Process.pid}-#{Time.now.to_i}"
      end
      
      if task_id.nil?
        task_id = "#{job_id}-#{Time.now.to_i}"
      end
      
      [job_id, task_id]
    end
    
    def get_node_name
      if @@this_node_name.nil?
        hostname = Socket.gethostname
        @@this_node_name = hostname.index(".").nil? ? hostname : hostname[0, hostname.index(".")]
      end
      @@this_node_name
    end
    
    def send_command(command, server=nil)
      server = @config.server if server.nil?
      begin
        send_command_to_server(command, server)
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
      [connection.send_command(command), server]
    end
  end
  
  
  #Error raised when unable to send command
  class ClientException < Exception
    
  end
end
