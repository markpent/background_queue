require 'optparse'
require 'logger'

module BackgroundQueue::ServerLib
  class Server
    
    attr_accessor :config
    attr_accessor :thread_manager
    attr_accessor :task_queue
    attr_accessor :error_tasks
    attr_accessor :event_server
    attr_accessor :workers
    attr_accessor :jobs
    attr_accessor :logger
    
    def initialize
      @running = false
      @stat_mutex = Mutex.new
      @stats = {
        :tasks=>0,
        :run_tasks=>0,
        :running=>0
      }
    end
    
    def process_args(argv)
      argv = argv.clone
      cmd = argv.shift
      
      if cmd.nil?
        raise BackgroundQueue::ServerLib::InitError, "Usage: server command [options]"
      end
      
      options = {:command=>cmd.nil? ? nil : cmd.downcase.intern}
      
      env_to_load = "development"
      
      OptionParser.new do |opts|
        opts.banner = "Usage: server command [options]"
        case options[:command]
          when :start, :test, :run
            opts.on("-c", "--config PATH", "Configuration Path") do |cp|
              options[:config] = cp
            end
          when :stop
            
          when nil
              
          else
            raise "Invalid Command: #{cmd}"
        end
        opts.on("-l", "--logfile [PATH]", "Logfile Path") do |lf|
          options[:log_file] = lf
        end
        opts.on("-v", "--loglevel [LEVEL]", "Log Level") do |ll|
          options[:log_level] = ll
        end
        opts.on("-p", "--pidfile [PATH]", "Pid file Path (/var/run/background_queue.pid)") do |pf|
          options[:pid_file] = pf
        end
        opts.on("-e", "--environment [RAILS_ENV]", "testing/development/production (development)") do |env|
          env_to_load = env
        end
        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end
      end.parse!(argv)
      
      ENV['RAILS_ENV']=env_to_load
      
      raise BackgroundQueue::ServerLib::InitError, "Missing config argument (-c)" if options[:config].nil? && ([:test, :start].include?(options[:command]) )
    
      options
    end
    
    def load_configuration(path)
      @config = BackgroundQueue::ServerLib::Config.load_file(path)
      true
    end
    
    def resolve_logging_path(path)
      File.expand_path(path)
    end
    
    def set_logging_level(log, level)
      if level.nil? || level.strip.length == 0
        level = "warn" 
      else
        level = level.to_s.downcase
      end
      case level
      when 'debug'
        log.level = Logger::DEBUG
      when 'info'
        log.level = Logger::INFO
      when 'warn'
        log.level = Logger::WARN
      when 'error'
        log.level = Logger::ERROR
      when 'fatal'
        log.level = Logger::FATAL
      else
        raise BackgroundQueue::ServerLib::InitError, "Unknown logging level: #{level}"
      end
    end
    
    def init_logging(path, level)
      unless path.nil? || path.to_s.strip.length == 0
        path = resolve_logging_path(path)
        begin
          @logger = Logger.new(path, "daily")
          set_logging_level(@logger, level)
        rescue Exception=>e
          raise BackgroundQueue::ServerLib::InitError, "Error initializing log file #{path}: #{e.message}"
        end
      end
      if @logger.nil?
        #just make a fallback logger...
        @logger = Logger.new($stderr)
        set_logging_level(@logger, "fatal")
      end
    end
    
    def get_pid_path(options)
      if options[:pid_file]
        options[:pid_file]
      else
        "/var/run/background_queue.pid"
      end
    end
    
    def get_pid(options)
      sPid = nil
      begin
        sPid = File.open(get_pid_path(options)) { |f|
          f.read
        }
      rescue
        return nil
      end
      return nil if sPid.nil? || sPid.to_i == 0
      nPid = sPid.to_i
      begin
        Process.kill(0, nPid)
        return nPid
      rescue
        return nil
      end
    end
    
    def check_not_running(options)
      proc_id = get_pid(options)
      raise BackgroundQueue::ServerLib::InitError, "Process #{proc_id} already running" unless proc_id.nil?
      nil
    end
    
    def stop_pid(options)
      proc_id = get_pid(options)
      unless proc_id.nil?
        begin
          Process.kill(15, proc_id) 
        rescue 
          #dont care... the process may have died already?
        end
        count = 0
        while get_pid(options) && count < 10
          puts "Waiting..."
          sleep(1)
        end
        kill_pid(options) #make sure
      end
    end
    
    def kill_pid(options)
      proc_id = get_pid(options)
      begin
        Process.kill(9, proc_id) unless proc_id.nil?
      rescue 
        #dont care... the process may have died already?
      end
    end
    
    def write_pid(options)
      proc_id = Process.pid
      begin
        File.open(get_pid_path(options), "w") { |f|
          f.write(proc_id.to_s)
        }
      rescue Exception=>e
        raise BackgroundQueue::ServerLib::InitError, "Unable to write to pid file #{get_pid_path(options)}: #{e.message}"
      end
    end
    
    def remove_pid(options)
      begin
        File.delete(get_pid_path(options))
      rescue 
      end
    end
    
    def trap_signals
      Signal.trap("TERM") do
        puts "Terminating..."
        self.stop()
      end
    end
    
    
    def daemonize(options)
      fork{
        stdin = open '/dev/null', 'r'
        stdout = open '/dev/null', 'w'
        stderr = open '/dev/null', 'w'
        STDIN.reopen stdin
        STDOUT.reopen stdout
        STDERR.reopen stderr
        fork{
          write_pid(options) unless options[:skip_pid]
          run(options)
        } and exit!
      }
    end
    
    def start(options)
      begin
        load_configuration(options[:config])
        init_logging(options[:log_file], options[:log_level])
        check_not_running(options) unless options[:skip_pid]
        write_pid(options) unless options[:skip_pid] #this will make sure we can write the pid file... the daemon will write it again
        if options[:command] == :start
          daemonize(options)
        elsif options[:command] == :run
          run(options)
        else
          raise BackgroundQueue::ServerLib::InitError, "Unknown Command: #{options[:command]}"
        end
      rescue BackgroundQueue::ServerLib::InitError=>ie
        STDERR.puts ie.message
      rescue Exception=>e
        STDERR.puts e.message
        STDERR.puts e.backtrace.join("\n")
      end
    end
    
    def running?
      @running
    end
    
    def run(options)
      trap_signals
      @running = true
      @thread_manager = BackgroundQueue::ServerLib::ThreadManager.new(self, self.config.connections_per_worker)
      
      @workers = BackgroundQueue::ServerLib::WorkerBalancer.new(self)
      @task_queue = BackgroundQueue::ServerLib::BalancedQueue.new(self)
      
      @thread_manager.start(BackgroundQueue::ServerLib::WorkerThread)
      
      @event_server = BackgroundQueue::ServerLib::EventServer.new(self)
      
      @error_tasks = BackgroundQueue::ServerLib::ErrorTaskList.new(self)
      
      @jobs = BackgroundQueue::ServerLib::JobRegistry.new
      
      load_tasks(config.task_file)
      
      @event_server.start
    end
    
    def stop(timeout_secs=10)
      @running = false
      @event_server.stop
      @thread_manager.wait(timeout_secs)
      @error_tasks.flush
      save_tasks(config.task_file)
    end
    
    def change_stat(stat, delta)
      @stat_mutex.synchronize {
        @stats[stat] += delta
      }
    end
    
    def get_stats
      @stat_mutex.synchronize {
         @stats.clone
      }
    end
    
    def load_tasks(path)
      return if path.nil?
      if File.exist?(path)
        begin
          File.open(path, 'r') { |io| 
            task_queue.load_from_file(io)
          }
        rescue Exception=>e
          logger.error("Error loading tasks from #{path}: #{e.message}")
          logger.debug(e.backtrace.join("\n"))
        end
      end
    end
    
    def save_tasks(path)
      return if path.nil?
      
      begin
        File.open(path, 'w') { |io| 
          task_queue.save_to_file(io)
        }
      rescue Exception=>e
        logger.error("Error saving tasks to #{path}: #{e.message}")
        logger.debug(e.backtrace.join("\n"))
      end
    end
  end
  
  class InitError < Exception
    
  end
end
