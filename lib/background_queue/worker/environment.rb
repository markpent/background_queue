module BackgroundQueue::Worker
  #holds the params, controller and response
  class Environment
    attr_reader :params
    attr_reader :owner_id 
    attr_reader :job_id
    attr_reader :task_id
    attr_reader :priority
    attr_reader :owner_id
    attr_reader :worker
    attr_reader :context
    attr_reader :logger
    attr_reader :summary
    attr_reader :step
    attr_reader :controller
    
    attr_reader :server_address
    
    attr_reader :output
    
    def initialize
      @params = {}
      @context = {}
    end
    
    def init_from_controller(controller)
      @controller = controller
      init_params(controller.params)
      if BackgroundQueue::Worker::Config.separate_logs?
        @logger = BackgroundQueue::Worker::Logger.init_logger(@worker, @owner_id, @job_id , @task_id, controller.logger.level)
      else
        @logger = controller.logger
      end   
      init_server_address(controller)
    end
    
    def init_params(controller_params)
      hash_data = nil
      begin
        hash_data = JSON.load(controller_params[:task])
      rescue Exception=>e
        raise "Invalid data format (should be json) when loading task from buffer: #{e.message}"
      end
      raise 'Invalid json root object (should be hash)' unless hash_data.kind_of?(Hash)
      
      @params = BackgroundQueue::Utils::AnyKeyHash.new(hash_data['params'])
      @owner_id = hash_data['owner_id']
      @job_id = hash_data['job_id']
      @task_id = hash_data['id']
      @priority = hash_data['priority']
      @worker = hash_data['worker']
      
      
      summary_data = nil
      begin
        summary_data = JSON.load(controller_params[:summary]) unless controller_params[:summary].nil?
      rescue Exception=>e
        raise "Invalid data format (should be json) when loading summary from buffer: #{e.message}"
      end
      if summary_data.nil?
        @summary = {}
      else
        @summary = BackgroundQueue::Utils::AnyKeyHash.new(summary_data)
      end
      @step = controller_params[:step]
    end
    
    def set_context(context)
      @context = context
    end
    
    def set_output(out)
      @output = out
    end
    
    def send_data(data)
      @output.write("#{data}\n")
      @output.flush
    end
    
    def init_server_address(controller)
      @server_address = BackgroundQueue::Worker::Environment::Server.new(controller.request.remote_ip, controller.params[:server_port])
    end
    
    def revert_environment
      
    end
    
    class Server
      attr_accessor :host
      attr_accessor :port
      
      def initialize(host, port)
        @host = host
        @port = port
      end
      
    end
    
    def set_process_name(max_memory=nil)
      prefix = nil
      unless BackgroundQueue::Worker::Config.process_name_prefix.nil?
        prefix = BackgroundQueue::Worker::Config.process_name_prefix + ":"
      end
      if BackgroundQueue::Worker::Config.support_process_monitoring
        prefix = "" if prefix.nil?
        timeout_at = Time.now.to_i + BackgroundQueue::Worker::Config.process_timeout
        if max_memory.nil?
          prefix << "TO[#{timeout_at}]:"
        else
          prefix << "TO[#{timeout_at}][#{max_memory}]:"
        end
      end
      
      unless prefix.nil?
        $0 = "#{prefix}#{self.worker}:#{self.owner_id}:#{self.job_id}:#{self.task_id}"
      end
    end
    
    def revert_process_name
      unless BackgroundQueue::Worker::Config.process_name_prefix.nil?
        $0 = "#{BackgroundQueue::Worker::Config.process_name_prefix}:idle"
      end
    end
    
  end
end
