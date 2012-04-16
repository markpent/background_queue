module BackgroundQueue::ServerLib
  module QueueRegistry
  
    def add_item(item)
      in_queue, queue = get_queue(get_queue_id_from_item(item))
      priority_increased, original_priority = track_priority_when_adding_to_queue(queue, item)
      if !in_queue || priority_increased
        if in_queue #remove from existing priority queue
          remove(queue, original_priority)
        end
        push(queue)
      end
    end
    
    def next_item
      item = nil
      queue = pop
      unless queue.nil?
        priority_decreased, original_priority, item = get_item_from_queue(queue)
        if queue.empty? || priority_decreased
          remove(queue, original_priority)
          @items.delete(queue.id) if queue.empty?
        end
        unless queue.empty?
          push(queue)
        end
      end
      item
    end
    
    private
    
    def create_queue(queue_id)
      self.class.queue_class.new(queue_id)
    end
    
    def track_priority_when_adding_to_queue(queue, item)
      original_priority = queue.priority
      add_item_to_queue(queue, item) #queue.add_item(item)
       
      if original_priority.nil? || original_priority > queue.priority
        return [true, original_priority]
      end
      [false, original_priority]
    end
    
    def get_item_from_queue(queue)
      original_priority = queue.priority
      item = queue.next_item
       
      if queue.priority.nil? || original_priority < queue.priority
        return [true, original_priority, item]
      end
      [false, original_priority, item]
    end
    
    def get_queue(queue_id)
      queue =  @items[queue_id]
      return [true, queue] unless queue.nil?
      queue = create_queue(queue_id) #BackgroundQueue::ServerLib::Owner.new(owner_id)
      @items[queue_id] = queue
      return [false, queue]
    end
    
  end
end
