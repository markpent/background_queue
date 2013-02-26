module BackgroundQueue::Worker
  #this module is mixed into the controller that will service the worker calls.
  #the action that will recive the worker calls should only call run_worker
  module Calling
  
    #call this method from within the controller action that receives the worker calls. 
    #pass the shared secret in to validate the call: this should equal the secret in the server config.
    def run_worker(context)
      return unless check_secret()
      worker = nil
      env = nil
      begin
        #setup worker environment
        env = init_environment(context)
        #get worker
        worker = BackgroundQueue::Worker::WorkerLoader.get_worker(env.worker)
        worker.set_environment(env)
      rescue Exception=>e
        logger.error("Error initializing worker: #{e.message}")
        logger.debug(e.backtrace.join("\n"))
        render :text=>"Error initializing worker: #{e.message}", :status=>500
        if defined?(handle_worker_error)
          handle_worker_error("INIT", e)
        else
          raise e
        end
        return false
      end
      call_worker(worker, env)
      true
    end
    
    def init_environment(context)
      env = BackgroundQueue::Worker::Environment.new
      env.init_from_controller(self)
      env.set_context(context)
      env
    end
    
    def set_process_name(env)
      unless BackgroundQueue::Worker::Config.process_name_prefix.nil?
        $0 = "#{BackgroundQueue::Worker::Config.process_name_prefix}:#{env.worker}:#{env.owner_id}:#{env.job_id}:#{env.task_id}"
      end
    end
    
    def revert_process_name
      unless BackgroundQueue::Worker::Config.process_name_prefix.nil?
        $0 = "#{BackgroundQueue::Worker::Config.process_name_prefix}:idle"
      end
    end
    
    def call_worker(worker, env)
      headers['X-Accel-Buffering'] = 'no' #passenger standalone uses nginx. This will turn buffering off in nginx
      render :text => lambda { |response,output| 
        env.set_output(output)
        set_process_name(env)
        begin
          case env.step
          when "start"
            worker.start
          when "finish"
            worker.finish
          else
            worker.run
          end
          worker.send_call_finished_status
        rescue Exception=>ex
          begin
            logger.error("Error calling worker: #{ex.message}")
            logger.error(ex.backtrace.join("\n"))
            worker.logger.error("Error calling worker: #{ex.message}")
            worker.logger.error(ex.backtrace.join("\n"))
            if defined?(handle_worker_error)
              handle_worker_error("CALL", ex)
            end
          rescue Exception=>nex
          end
          worker.send_fatal_error("Fatal Error: #{ex.message}")
        ensure
          worker.set_environment(nil)
          revert_process_name
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
