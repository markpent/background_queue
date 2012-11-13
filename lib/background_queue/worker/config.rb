module BackgroundQueue::Worker
  class Config
      
    @@worker_path = nil
    @separate_logs = false
    @@process_name_prefix = "bgq"
    
    def self.secret=(auth)
      @@secret = auth
    end
    
    def self.secret
      @@secret
    end
    
    def self.worker_path=(path)
      @@worker_path = path
    end
    
    def self.worker_path
      if @@worker_path.nil?
        default_worker_path
      else
        @@worker_path
      end
    end
    
    def self.default_worker_path
      if defined?(RAILS_ROOT)
        File.join(RAILS_ROOT, "lib", "bgq_workers")
      elsif defined?(Rails) 
        File.join(Rails.root, "lib", "bgq_workers")
      else
        raise "You must specify the BackgroundQueue::Worker::Config.worker_path"
      end
    end
    
    def self.separate_logs=(use_separate_logs)
      @separate_logs = use_separate_logs
    end
    
    #should the worker have its own log file per instance? (makes it easier to backtrack errors)
    #if true, the log file is based on the job id. Each log line will have the task id.
    def self.separate_logs?
      @separate_logs
    end
    
    
    def self.process_name_prefix=(prefix)
      @@process_name_prefix = prefix
    end
    
    def self.process_name_prefix
      @@process_name_prefix
    end
  end
end
