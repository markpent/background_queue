module BackgroundQueue::ServerLib
  
  class Owner < PriorityQueue
    
    attr_accessor :id
    
    def initialize(id)
      @id = id
      super()
    end
    
    def add_task(task)
      #original_priority = priority
      #push(task)
      # 
      #if original_priority.nil? || original_priority > priority
      #  return [true, original_priority]
      #end
      #[false, original_priority]
    end
    
    def next_task
      
    end
    
    def ==(other)
      @id == other.id
    end
    
    def inspect
      "#{self.id}"
    end
    
    private
    
    def build_item(id)
      
    end
    
    

  end
end
