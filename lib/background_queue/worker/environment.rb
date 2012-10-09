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
    attr_reader :logger
    
    attr_reader :server_address
    
    attr_reader :output
    
    def initialize
      @params = {}
    end
    
    def init_from_controller(controller)
      @controller = controller
      @logger = controller.logger
      init_params(controller.params)
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
    
    class Server
      attr_accessor :host
      attr_accessor :port
      
      def initialize(host, port)
        @host = host
        @port = port
      end
      
    end
    
  end
end