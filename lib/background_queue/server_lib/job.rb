module BackgroundQueue::ServerLib
  class Job < PriorityQueue
  
    attr_accessor :id
    
    def initialize(id)
      @id = id
      super()
    end

    def ==(other)
      @id == other.id
    end
    
    def inspect
      "#{self.id}"
    end

    def add_item(task)
      push(task)
    end
    
    def next_item
      pop
    end
  end
end
