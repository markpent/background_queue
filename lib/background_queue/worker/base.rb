module BackgroundQueue::Worker
  #the base class of workers
  class Base
  
    def initialize
      @environment = nil
    end
    
    def set_environment(env)
      #puts "set_environment=#{env}"
      @environment = env
    end
    
    def environment
      @environment
    end
    
    #update the progress of the currently running task
    def set_progress(caption, percent)
      #puts self
      #puts "env=#{self.environment}"
      self.environment.send_data({:caption=>caption, :percent=>percent}.to_json)
    end
    
    #add meta data to the progress
    #key: :notice, :warning, :error, :meta
    #value: :notice/:warning/:error : String, :meta : any json compatible object
    def add_progress_meta(key, value)
      self.environment.send_data({:meta=>{key=>value}}.to_json)
    end
    
    #virtual function: called to process a worker request
    def run
      raise "run() Not Implemented on worker #{self.class.name}"
    end
    
    def params
      self.environment.params
    end
    
    def logger
      self.environment.logger
    end
    
  end
end
