module BackgroundQueue::Worker
  #this module is mixed into the controller that will service the worker calls.
  #the action that will recive the worker calls should only call run_worker
  module Calling
  
    #call this method from within the controller action that receives the worker calls. 
    #pass the shared secret in to validate the call: this should equal the secret in the server config.
    def run_worker
      return unless check_secret()
      worker = nil
      env = nil
      begin
        #setup worker environment
        env = init_environment
        #get worker
        worker = BackgroundQueue::Worker::WorkerLoader.get_worker(env.worker)
        worker.set_environment(env)
      rescue Exception=>e
        logger.error("Error initializing worker: #{e.message}")
        logger.debug(e.backtrace.join("\n"))
        render :text=>"Error initializing worker: #{e.message}", :status=>500
        raise e
      end
      #puts worker
      #call worker
      call_worker(worker, env)
      true

    end
    
    def init_environment
      env = BackgroundQueue::Worker::Environment.new
      env.init_from_controller(self)
      env
    end
    
    def call_worker(worker, env)
      headers['X-Accel-Buffering'] = 'no' #passenger standalone uses nginx. This will turn buffering off in nginx
      render :text => lambda { |response,output| 
        env.set_output(output)
        begin
          worker.run
        rescue Exception=>e
          logger.error("Error calling worker: #{e.message}")
          logger.error(e.backtrace.join("\n"))
        ensure
          worker.set_environment(nil)
        end
      }, :type=>"text/text"
    end
    
    def check_secret
      return true if params[:auth] == BackgroundQueue::Worker::Config.secret
      render :text=>"Invalid auth (#{params[:auth]})", :status=>401
      false
    end
    
  end
end
