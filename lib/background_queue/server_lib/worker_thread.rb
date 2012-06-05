
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
      while @server.running?
        worker = @server.workers.get_next_worker
        if worker.nil?
          Kernel.sleep(1)
        else
          client = build_client
          if client.send_request(worker, task, @server.config.secret)
            @server.workers.finish_using_worker(worker, true)
            return true
          else
            @server.workers.finish_using_worker(worker, false)
          end
        end
      end
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
