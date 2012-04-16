require 'thread'
module BackgroundQueue::ServerLib
  
  class BalancedQueue < PriorityQueue
    include BackgroundQueue::ServerLib::QueueRegistry
    def initialize
      
      @condvar = ConditionVariable.new
      @mutex = Mutex.new
      super
    end
    
    def add_task(task)
      @mutex.synchronize {
        add_item(task)
        @condvar.signal #wake anything reading from the queue
      }
    end
    
    def next_task
      task = nil
      @mutex.synchronize {
        task = next_item
        if task.nil?
          @condvar.wait
        end
      }
      task
    end
    
    def self.queue_class
      BackgroundQueue::ServerLib::Owner
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
