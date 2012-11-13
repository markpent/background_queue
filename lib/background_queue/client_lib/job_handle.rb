require 'digest/md5'
module BackgroundQueue::ClientLib
  #returned from add_task to describe what the job/server was added.
  #this is because you can call add_task without a job_id, and not know what server was used.
  #this is passed to get_status
  class JobHandle
    
    attr_reader :owner_id
    attr_reader :job_id
    attr_reader :server
    
    def initialize(owner_id, job_id, server)
      @owner_id = owner_id
      @job_id = job_id
      @server = server
    end
    
    #register this job and return the registered key
    def register(session_id)
      md5 = Digest::MD5::new
      now = Time::now
      md5.update(now.to_s)
      md5.update(String(now.usec))
      md5.update(String(rand(0)))
      md5.update(String($$))
      md5.update('foobar')
      md5.update(owner_id.to_s)
      md5.update(job_id.to_s)
      md5.update(server.to_s)
      key = md5.hexdigest
          
      Cache.put("#{session_id}_#{key}", self )
      
      reverse_key = [owner_id, job_id, server].join("_")
      Cache.put("#{session_id}_#{reverse_key}", key )
    end
    
    #look up a job from the key returned from register
    def self.get_registered_job(session_id, key)
      Cache.get("#{session_id}_#{key}")
    end
    
    #find the key for this job if its already registeed
    def get_registration_key(session_id)
      reverse_key = [owner_id, job_id, server].join("_")
      Cache.get("#{session_id}_#{reverse_key}")
    end
    
  
  end

end
