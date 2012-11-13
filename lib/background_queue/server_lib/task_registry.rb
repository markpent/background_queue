module BackgroundQueue::ServerLib
  
  #keep track if tasks already queued and running so if the same task comes in, we know to remove it.
  class TaskRegistry
  
    def initialize
      @waiting_tasks = {}
      @tasks = {}
    end
    
    def register(task)
      existing_task = @tasks[task.id]
      if existing_task.nil? 
        #puts "nil task"
        @tasks[task.id] = task
        [:new, nil]
      elsif existing_task.running?
        #puts "task running"
        register_waiting_task(task)
        [:waiting, nil]
      elsif existing_task.waiting_to_retry?
        #puts "task waiting_to_retry"
        @tasks[task.id] = task
        [:waiting_to_retry, existing_task]
      else
        #puts "task waiting"
        @tasks[task.id] = task
        [:existing, existing_task]
      end
    end
    
    def de_register(task_id)
      @tasks.delete(task_id)
      waiting = get_waiting_task(task_id)
      if waiting
        @tasks[task_id] = waiting
      end
      waiting
    end
    
    def register_waiting_task(task)
      @waiting_tasks[task.id] = task
    end
    
    def get_waiting_task(task_id)
      @waiting_tasks.delete(task_id)
    end
    
    def waiting_tasks
      @waiting_tasks
    end
    
    def tasks
      @tasks
    end
  end

end
