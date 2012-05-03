require 'optparse'
require 'logger'

module BackgroundQueue::ServerLib
  class Server
    
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
  end
end
