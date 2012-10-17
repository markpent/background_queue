require 'algorithms'
module BackgroundQueue::ServerLib
  
  class ErrorTaskList
  
    attr_reader :tasks
    attr_reader :task_count
    
    def initialize(server)
      @server = server
      @tasks = Containers::RBTreeMap.new
      @mutex = Mutex.new
      @current_next_at = nil
      @current_runner = nil
      @task_count = 0
    end
    
    def add_task(task)
      task.increment_error_count
      delay = calculate_delay(task.get_error_count)             
      add_item(task, Time.now.to_i + delay)
    end
    
    def calculate_delay(error_count)
      delay = error_count * error_count
      delay > 120 ? 120 : delay
    end
    
    def add_item(task, time_at)
      @mutex.synchronize {
        existing = @tasks[time_at]
        if existing.nil?
          existing = []
          @tasks[time_at] = existing
        end
        existing << task
        @task_count += 1
        queue_next_event(time_at)
      }
      @server.logger.debug("Task #{task.id} queued to retry in #{time_at - Time.now.to_f} seconds")
    end
    
    def queue_next_event(time_at)
      if @current_next_at.nil? || @current_next_at > time_at
        @current_runner.cancel if @current_runner
        @current_next_at = time_at
        @current_runner = BackgroundQueue::ServerLib::ErrorTaskList::RunAt.new(time_at) {
          self.next_event
        }
      end
    end
    
    def next_event
      @mutex.synchronize {
        @current_runner = nil
        @current_next_at = nil
        while @tasks.size > 0 && @tasks.min_key < (Time.now.to_f + 0.1)
          next_tasks = @tasks.delete_min
          for task in next_tasks
            @server.task_queue.finish_task(task)
            @server.task_queue.add_task(task)
            @task_count -= 1
          end
        end
        queue_next_event(@tasks.min_key) if @tasks.size > 0
      }
    end
    
    def flush
      @server.logger.debug("Flushing #{@tasks.size} tasks from error list")
      @current_runner.cancel if @current_runner
      @current_runner = nil
      @mutex.synchronize {
        while @tasks.size > 0
          next_tasks = @tasks.delete_min
          for task in next_tasks
            @server.task_queue.finish_task(task)
            @server.task_queue.add_task(task)
            @task_count -= 1
          end
        end
      }
    end
    
    def wait_for_event
      runner = @current_runner
      runner.wait_for_run if runner
    end
    
    class RunAt
      #i dont care about thread safety: it doesnt matter if an event runs twice.
      def initialize(at, &block)
        @running = true
        @th = Thread.new {
          delay = at - Time.now.to_f 
          sleep(delay)
          if @running
            block.call
            @running = false
          end
        }
      end
      
      def cancel
        return false if !@running
        @running = false
        @th.run #wake the sleep up
      end
      
      def wait_for_run
        @th.join
      end
      
    end
  end
end
