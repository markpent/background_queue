require 'thread'
module BackgroundQueue::ServerLib
  
  class BalancedQueue < PriorityQueue
    
    def initialize
      @items = {}
      @condvar = ConditionVariable.new
      @mutex = Mutex.new
      super
    end
    
    def add_task(task)
      @mutex.synchronize {
        in_queue, owner = get_owner_queue(task.owner_id)
        priority_increased, original_priority = add_task_to_owner(owner, task)
        if !in_queue || priority_increased
          if in_queue #remove from existing priority queue
            remove(owner, original_priority)
          end
          push(owner)
        end
        @condvar.signal #wake anything reading from the queue
      }
    end
    
    def next_task
      task = nil
      @mutex.synchronize {
        owner = pop
        if owner.nil?
          @condvar.wait
        else
          priority_decreased, original_priority, task = get_task_from_owner(owner)
          if owner.empty? || priority_decreased
            remove(owner, original_priority)
            @items.delete(owner.id) if owner.empty?
          end
          unless owner.empty?
            push(owner)
          end
        end
      }
      task
    end
    
    
    private
    
    def add_task_to_owner(owner, task)
      original_priority = owner.priority
      owner.add_task(task)
       
      if original_priority.nil? || original_priority > owner.priority
        return [true, original_priority]
      end
      [false, original_priority]
    end
    
    def get_task_from_owner(owner)
      original_priority = owner.priority
      task = owner.next_task
       
      if owner.priority.nil? || original_priority < owner.priority
        return [true, original_priority, task]
      end
      [false, original_priority, task]
    end
    
    def get_owner_queue(owner_id)
      owner =  @items[owner_id]
      return [true, owner] unless owner.nil?
      owner = BackgroundQueue::ServerLib::Owner.new(owner_id)
      @items[owner_id] = owner
      return [false, owner]
    end
    
    

  end
end
