module BackgroundQueue::Worker
  class Logger < Logger
  
    def initialize(logdev, task_key)
			super(logdev, 0, 1048576)
			@default_formatter = BackgroundQueue::Worker::LogFormatter.new(task_key)
		end
		
		def set_previous_state(previous_state)
		  @previous_state = previous_state
		end
			
		def format_message(severity, datetime, progname, msg)
			(@formatter || @default_formatter).call(severity, datetime, progname, msg)
		end
		
		def self.init_logger(worker_name, owner_key, job_key, task_key, level)
		  logger = build_logger("#{BackgroundQueue::Utils.current_root}/log/workers/#{worker_name}-#{owner_key}-#{job_key}.log", task_key, level)
		  
		  prev_state = {}
		  
		  #we also want to have active record use this log file
		  if defined? ActiveRecord && defined? ActiveRecord::Base && ActiveRecord::Base.class.respond_to?(:logger)
		    begin
          prev_state[:ar_base] = ActiveRecord::Base.logger
          ActiveRecord::Base.logger = logger
          
          if ActiveRecord::Base.respond_to?(:active_connections)
            #set the logger for connections that are already loaded
            ActiveRecord::Base.active_connections.each_value { |con| con.set_logger(ActiveRecord::Base.logger)}
          end
        rescue Exception=>e
          logger.debug("Error setting up active record logger: #{e.message}")
        end
		  end
		  
		  #and RAILS_DEFAULT_LOGGER
		  if defined?(RAILS_DEFAULT_LOGGER)
		    prev_state[:rails_default_logger] = RAILS_DEFAULT_LOGGER
        Object.redefine_const(
          :RAILS_DEFAULT_LOGGER,
          logger
        )
		  end
      
		  logger.set_previous_state(prev_state) unless prev_state.empty?
      logger
		end
		
		def self.build_logger(path, task_key, level)
		  logger = BackgroundQueue::Worker::Logger.new(path, task_key)
		  logger.level = level
		  logger
		end
		
		def revert_to_previous_state
		  unless @previous_state.nil?
		    if @previous_state[:ar_base]
		      ActiveRecord::Base.logger = @previous_state[:ar_base]
		      if ActiveRecord::Base.respond_to?(:active_connections)
            #set the logger for connections that are already loaded
            ActiveRecord::Base.active_connections.each_value { |con| con.set_logger(ActiveRecord::Base.logger)}
          end
		    end
		    if @previous_state[:rails_default_logger]
		      Object.redefine_const(
            :RAILS_DEFAULT_LOGGER,
            @previous_state[:rails_default_logger]
          )
		    end
		  end
		end
  end
  
  
  #custom log formatter
	class LogFormatter < Logger::Formatter
		Format = "%s %5s [%s] %s\n"
		
		def initialize(task_key)
      @datetime_format = "%Y-%m-%d %H:%M:%S"
      @task_key = task_key
    end
		
		def call(severity, time, progname, msg)
      Format % [@task_key, severity, format_datetime(time), msg2str(msg)]
    end
	end
end

#allow us to redifine constants (RAILS_DEFAULT_LOGGER)
unless  Module.respond_to?(:redefine_const)
  class Module
    def redefine_const(name, value)
      __send__(:remove_const, name) if const_defined?(name)
      const_set(name, value)
    end
  end
end


#need to be able to set the current logger for existing connections...
if defined? ActiveRecord && defined? ActiveRecord::ConnectionAdapters && defined? ActiveRecord::ConnectionAdapters::AbstractAdapter
  module ActiveRecord
    module ConnectionAdapters # :nodoc:
      class AbstractAdapter
        def set_logger(logger)
          @logger = logger
        end
      end
    end
  end
end

