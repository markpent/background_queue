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
    
    def context
      @environment.context
    end
    
    #update the progress of the currently running task
    def set_progress(caption, percent)
      #puts self
      #puts "env=#{self.environment}"
      logger.debug("set_progress(#{caption}, #{percent})")
      self.environment.send_data({:caption=>caption, :percent=>percent}.to_json)
    end
    
    #add meta data to the progress
    #key: :notice, :warning, :error, :meta
    #value: :notice/:warning/:error : String, :meta : any json compatible object
    def add_progress_meta(key, value)
      logger.debug("add_progress_meta(#{key}, #{value.to_json})")
      self.environment.send_data({:meta=>{key=>value}}.to_json)
    end
    
    def append_summary(type, data)
      raise "Missing Type when appending summary" if type.nil?
      self.environment.send_data({:summary=>"app", :type=>type.to_s, :data=>data}.to_json)
    end
    
    def set_summary(type, key, data)
      raise "Missing Type when settind summary" if type.nil?
      raise "Missing key when settind summary" if key.nil?
      self.environment.send_data({:summary=>"set", :type=>type.to_s, :key=>key, :data=>data}.to_json)
    end
    
    def increment_summary(type, amount=1)
      raise "Missing Type when incrementing summary" if type.nil?
      self.environment.send_data({:summary=>"inc", :type=>type.to_s, :data=>amount}.to_json)
    end
    
    def decrement_sumary(type, amount=1)
      raise "Missing Type when decrementing summary" if type.nil?
      self.environment.send_data({:summary=>"dec", :type=>type.to_s, :data=>amount}.to_json)
    end
    
    def reset_summary(type)
      self.environment.send_data({:summary=>"res", :type=>type.to_s}.to_json)
    end
    
    def send_fatal_error(error_message)
      self.environment.send_data({:error=>error_message}.to_json)
    end
    
    def send_call_finished_status
      self.environment.send_data({:finished=>true}.to_json)
    end
    
    #virtual function: called to process a worker request
    def run
      raise "run() Not Implemented on worker #{self.class.name}"
    end
    
    #virtual function: called to process a worker request (step=start)
    def start
      raise "start() Not Implemented on worker #{self.class.name}"
    end
    
    #virtual function: called to process a worker request (step=finish)
     def finish
      raise "finish() Not Implemented on worker #{self.class.name}"
    end
    
    def params
      self.environment.params
    end
    
    def logger
      self.environment.logger
    end
    
    def summary
      self.environment.summary
    end
    
  end
end
