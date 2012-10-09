module BackgroundQueue::Worker
  class Config
      
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
    
  end
end
