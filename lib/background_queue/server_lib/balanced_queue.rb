require 'thread'
module BackgroundQueue::ServerLib
  
  class BalancedQueue < PriorityQueue
    include BackgroundQueue::ServerLib::QueueRegistry
    
    def initialize(server)
      @task_registry = BackgroundQueue::ServerLib::TaskRegistry.new
      @condvar = ConditionVariable.new
      @mutex = Mutex.new
      @server = server
      @thread_manager = server.thread_manager
      super()
    end
    
    def add_task(task)
      @thread_manager.protect_access {
        status, existing_task = @task_registry.register(task)
        if status != :waiting
          if status == :existing
            remove_task(existing_task)
          end
          add_item(task)
          @thread_manager.signal_access #wake anything reading from the queue
        end
      }
    end
    
    def remove_task(task)
      @thread_manager.protect_access {
        remove_item(task)
      }
    end
    
    def next_task
      task = nil
      @thread_manager.control_access {
        task = next_item
        if task.nil?
          @thread_manager.wait_on_access
        end
      }
      task
    end
    
    def self.queue_class
      BackgroundQueue::ServerLib::Owner
    end
    
    def register_job(job)
      @server.jobs.register(job)
    end
    
    private
    
    def get_queue_id_from_item(item)
      item.owner_id
    end
    
    def add_item_to_queue(queue, item)
      queue.add_item(item)
    end
    

  end
end
