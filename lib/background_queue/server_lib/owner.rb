module BackgroundQueue::ServerLib
  
  class Owner < PriorityQueue
    include BackgroundQueue::ServerLib::QueueRegistry
    
    attr_accessor :id
    
    def initialize(id, balanced_queues)
      @id = id
      @balanced_queues = balanced_queues
      super()
    end

    
    def ==(other)
      @id == other.id
    end
    
    def inspect
      "#{self.id}"
    end

    def self.queue_class
      BackgroundQueue::ServerLib::Job
    end
    
    private
    
    def get_queue_id_from_item(item)
      item.job_id
    end
    
    def add_item_to_queue(queue, item)
      queue.add_item(item)
    end
    
    

  end
end
