module BackgroundQueue::ServerLib
  class Job < PriorityQueue
  
    attr_accessor :id
    
    def initialize(id, owner)
      @id = id
      @owner = owner
      super()
    end

    def ==(other)
      @id == other.id
    end
    
    def inspect
      "#{self.id}"
    end

    def add_item(task)
      task.set_job(self)
      push(task)
    end
    
    def next_item
      pop
    end
  end
end
