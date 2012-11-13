#The Background Queue will schedule tasks in the background. Refer to README for more details. 
module BackgroundQueue
  #The main interface to the background queue from the client.
  #this class will look after sending a command to the server, using a failover server if needed.
  class Client
    
    attr_accessor :config
    
    def initialize(path)
      @config = BackgroundQueue::ClientLib::Config.load_file(path)
    end
    
    #Add a task to the background
    #
    # @param [Symbol] worker name of the worker, ie :some_background_worker
    # @param [Symbol, String, Number] owner_id something that identified the owner of the task. This will make sure resources are divided between owners equally.
    # @param [Symbol, String, Number] job_id something to idetify the job. Tracking occurs per job.
    # @param [Symbol, String, Number] task_id a globally unique id for the task. If the task_id exists elsewhere, it will be removed and added to the owner/job queue specified.
    # @param [Integer] priority priority for 1 (highest) to 5 (lowest). Used to determine order of jobs.
    # @param [Hash] task_parameters a hash of parameters passed to the task
    # @param [Hash] options a hash of options that effect how the task is executed.
    # @option options [String] :domain the domain to set in the host header when calling the worker.
    # @option options [Boolean] :exclude if true, will not be included in (x/y) counter of progress caption
    # @option options [Boolean] :synchronous if true, the task is synchronous, and no other tasks in the job will run until it is finished
    # @option options [Number] :weight the weight of the task. Usually its weight is the same as other tasks in job
    # @option options [String] :initial_progress_caption the progress caption to display until the job has started reporting progress
    # @option options [Boolean] :send_summary if true, the task will receive the summary data
    # @option options [Symbol] :step the step to run, `:start`, `:run` (Default) or `:finish` 
    #
    # @return [BackgroundQueue::ClientLib::JobHandle] A handle to the job which can be used in get_status
    
    def add_task(worker, owner_id, job_id, task_id, priority, task_parameters={}, options={}, server=nil )
      job_id, task_id = generate_ids(worker, owner_id, job_id, task_id)
      result, server = send_command(BackgroundQueue::ClientLib::Command.add_task_command(worker, owner_id, job_id, task_id, priority, task_parameters, options ), server)
      #the server currently either returns :ok or an exception would have been thrown
      BackgroundQueue::ClientLib::JobHandle.new(owner_id, job_id, server)
    end
    
    #Add multiple tasks to the background, all with the same worker/owner/job
    #
    # @param [Symbol] worker name of the worker, ie :some_background_worker
    # @param [Symbol, String, Number] owner_id something that identified the owner of the task. This will make sure resources are divided between owners equally.
    # @param [Symbol, String, Number] job_id something to idetify the job. Tracking occurs per job.
    # @param [Array<Array<String, Hash, Hash>>] tasks an array of arrays in the format [task_id, optional task_params (Hash), optional task_options (Hash)]
    # @param [Integer] priority priority for 1 (highest) to 5 (lowest). Used to determine order of jobs.
    # @param [Hash] shared_parameters a hash of parameters passed to the tasks. This is merged with the task_params specified in the tasks param.
    # @param [Hash] options a hash of options that effect how the tasks are executed. This is merged with the task_options specified in the tasks param. Refer to {#add_task} for options.
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
