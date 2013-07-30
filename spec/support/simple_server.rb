class SimpleServer
  attr_accessor :config
  attr_accessor :thread_manager
  attr_accessor :task_queue
  attr_accessor :event_server
  attr_accessor :workers
  attr_accessor :jobs
  attr_accessor :logger
  attr_accessor :error_tasks
  
  def initialize(options={})
    @logger = Logger.new("/dev/null")
    @config = options[:config]
    @thread_manager = options[:thread_manager]
    @task_queue = options[:task_queue]
    @event_server = options[:event_server]
    @workers = options[:workers]
    @jobs = options[:jobs]
    @error_tasks = options[:error_tasks]
  end
  
  def running?
    true
  end
  
  def change_stat(stat, delta)
    
  end
  
  def report_error(subject, message)
  end
 
end
