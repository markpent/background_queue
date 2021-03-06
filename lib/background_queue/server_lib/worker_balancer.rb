module BackgroundQueue::ServerLib
  #make sure each worker gets its fair share of tasks
  #track the number of active connections to use as the balancing metric
  class WorkerBalancer
    
    attr_reader :available_workers
    attr_reader :offline_workers
    
    def initialize(server)
      @server = server
      @mutex = Mutex.new
      @offline_workers = []
      @available_workers = SortedWorkers.new
      for worker_config in server.config.workers.reverse
        worker = Worker.new(worker_config.uri)
        @available_workers.add_worker(worker)
      end
    end
    
    def monitor_offline_workers
      @check_offline_servers_thread = Thread.new {
        while @server.running?
          check_offline
          sleep(1)
        end
      }
    end
    
    def finish_monitoring_offline_servers
      unless @check_offline_servers_thread.nil?
        @check_offline_servers_thread.wakeup
        @check_offline_servers_thread.join
      end
    end
    
    #poll the workers that are marked as offline, and mark them online if the polling succeeded
    def check_offline
      
      workers_to_check = @mutex.synchronize { @offline_workers.clone }

      for worker in workers_to_check
        client = BackgroundQueue::ServerLib::WorkerClient.new(@server)
        @server.logger.debug("Polling #{worker.uri}")
        if client.send_request(worker, build_poll_task, @server.config.secret)
          @server.logger.debug("Polled #{worker.uri} successfully")
          register_online(worker)
        end
      end
    end
    
    #get the worker with the least number of connections using it
    def get_next_worker
      @mutex.synchronize { 
        worker = @available_workers.worker_list.first 
        unless worker.nil?
          register_start(worker)
        end
        worker
      }
    end
    
    def finish_using_worker(worker, online)
      @mutex.synchronize { 
        if online
          register_finish(worker)
        else
          register_offline(worker)
        end
      }
    end
    
    private
    
    def register_start(worker)
      worker.connections += 1
      @available_workers.adjust_worker(worker)
    end
    
    def register_finish(worker)
      worker.connections -= 1
      @available_workers.adjust_worker(worker)
    end
    
    def register_offline(worker)
      worker.connections -= 1
      unless worker.offline?
        worker.offline = true
        @available_workers.remove_worker(worker)
        @offline_workers << worker
      end
    end
    
    def register_online(worker)
      if worker.offline?
        worker.offline = false
        @offline_workers.delete(worker)
        @available_workers.add_worker(worker)
      end
    end
    
    def build_poll_task
      if @poll_task.nil?
        @poll_task = BackgroundQueue::ServerLib::Task.new(:polling_owner_id, :polling_job_id, :polling_task_id, 1, :poll_worker, {}, @server.config.system_task_options)
        @poll_task.set_job(BackgroundQueue::ServerLib::NullJob.new)
      end
      @poll_task
    end
  end
  
  class NullJob
    def set_worker_status(status)
      #do nothing
    end
  end
end
