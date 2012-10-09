require 'thread'
module BackgroundQueue::ServerLib
  
  class BalancedQueue < PriorityQueue
    include BackgroundQueue::ServerLib::QueueRegistry
    
    attr_reader :server
    
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
            remove_item(existing_task)
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
    
    def finish_task(task)
      @thread_manager.protect_access {
        finish_item(task)
        existing_task = @task_registry.de_register(task.id)
        if existing_task
          add_item(task)
        end
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
    
    def synchronous?
      false
    end
    
    def save_to_file(io)
      data = []
      @server.logger.debug("Saving task queue to file")
      @thread_manager.protect_access {
        each_item { |owner|
          owner.each_item { |job|
            job.each_item { |task|
              data << task.to_json_object(true)
            }
          }
        }
      }
      @server.logger.debug("Writing #{data.length} entries to file")
      io.write(JSON.fast_generate(data))
    end
    
    def load_from_file(io)
      @server.logger.debug("Loading task queue from file")
      tasks = JSON.parse(io.read, :symbolize_names=>true)
      @server.logger.debug("Adding #{tasks.length} tasks from file")
      for task_data in tasks
        task = Task.new(task_data[:owner_id], task_data[:job_id], task_data[:id], task_data[:priority], task_data[:worker], task_data[:params], task_data[:options])
        add_task(task)
      end
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
