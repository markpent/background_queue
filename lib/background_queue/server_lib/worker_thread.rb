
module BackgroundQueue::ServerLib
  #A Thread that processes the task queue
  class WorkerThread
  
    def initialize(server)
      @server = server
    end
      
    def get_next_task
      task = nil
      while @server.running? && task.nil?
        task = @server.task_queue.next_task
      end
      task = nil if task.nil? || !@server.running? #if the server isnt running, dont continue to process a task
      task
    end
    
    def build_client
      BackgroundQueue::ServerLib::WorkerClient.new(@server)
    end
    
    def call_worker(task)
      @server.change_stat(:tasks, -1)
      @server.change_stat(:running, 1)
      @server.logger.debug("calling worker for task #{task.id}")
      error_count = 0
      while @server.running?
        worker = @server.workers.get_next_worker
        if worker.nil?
          Kernel.sleep(1) unless !@server.running?
        else
          client = build_client
          result = client.send_request(worker, task, @server.config.secret)
          if result == :ok
            @server.logger.debug("called worker for task #{task.id}")
            @server.workers.finish_using_worker(worker, true)
            @server.task_queue.finish_task(task)
            @server.change_stat(:running, -1)
            @server.change_stat(:run_tasks, 1)
            return true
          else
            @server.logger.debug("failed calling worker for task #{task.id}")
            @server.workers.finish_using_worker(worker, result == :worker_error)
            @server.error_tasks.add_task(task)
            return result != :stop
            #error_count += 1
            #if error_count > 5
            #  @server.logger.debug("error count exceeded for task #{task.id}, returning to queue")
            #  @server.task_queue.finish_task(task)
            #  @server.task_queue.add_task(task)
            #  return true
            #end
          end
        end
      end
      #if we get here the server stopped before we could do the task... put it back so it can be saved to disk...
      @server.logger.debug("returning task #{task.id} to queue because the server has stopped")
      @server.task_queue.finish_task(task)
      @server.task_queue.add_task(task)
      
      false
    end
    
    def run
      while @server.running?
        task = get_next_task
        call_worker(task) unless task.nil?
      end
    end
  end
end
