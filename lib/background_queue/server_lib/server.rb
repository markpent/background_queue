require 'optparse'
require 'logger'

module BackgroundQueue::ServerLib
  class Server
    
    attr_accessor :config
    
    
    def process_args(argv)
      argv = argv.clone
      cmd = argv.shift
      options = {:command=>cmd.downcase.intern}
     
      OptionParser.new do |opts|
        opts.banner = "Usage: server command [options]"
        case options[:command]
          when :start, :test
            opts.on("-c", "--config PATH", "Configuration Path") do |cp|
              options[:config] = cp
            end
          when :stop
        
          else
            raise "Invalid Command: #{cmd}"
        end
        opts.on("-l", "--logfile [PATH]", "Logfile Path") do |lf|
          options[:log_file] = lf
        end
        opts.on("-v", "--loglevel [LEVEL]", "Log Level") do |ll|
          options[:log_level] = ll
        end
        opts.on("-p", "--pidfile [PATH]", "Pid file Path") do |pf|
          options[:pid_file] = pf
        end
      end.parse!(argv)
      
      raise "Missing config argument (-c)" if options[:config].nil? && ([:test, :start].include?(options[:command]) )
    
      options
    end
    
    def load_configuration(path)
      @config = BackgroundQueue::ServerLib::Config.open_file(path)
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
        raise "Unknown logging level: #{level}"
      end
    end
    
    def init_logging(path, level)
      return if path.nil? || path.to_s.strip.length == 0
      path = resolve_logging_path(path)
      begin
        @logger = Logger.new(path, "daily")
        set_logging_level(@logger, level)
      rescue Exception=>e
        raise "Error initializing log file #{path}: #{e.message}"
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
      raise "Process #{proc_id} already running" unless proc_id.nil?
      nil
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
        raise "Unable to write to pid file #{get_pid_path(options)}: #{e.message}"
      end
    end
    
    def remove_pid(options)
      begin
        File.delete(get_pid_path(options))
      rescue 
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
          run(options)
        } and exit!
      }
    end
    
    def start(options)
      begin
        load_configuration(options[:config])
        init_logging(options[:log_file], options[:log_level])
        check_not_running(options)
        write_pid(options)
        if options[:command] == :start
          daemonize(options)
        elsif options[:command] == :run
          run(options)
        else
          raise "Unknown Command: #{options[:command]}"
        end
      rescue Exception=>e
        STDERR.puts e.message
      end
    end
  end
end
