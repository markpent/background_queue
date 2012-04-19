module BackgroundQueue::ServerLib
  module QueueRegistry
  
    def add_item(item)
      in_queue, queue = get_queue(get_queue_id_from_item(item), true)
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
        priority_decreased, original_priority, item = remove_item_from_queue(queue, :next)
        if queue.empty?
          @items.delete(queue.id) 
        else
          push(queue)
        end
      end
      item
    end
    
    def remove_item(item)
      in_queue, queue = get_queue(get_queue_id_from_item(item), false)
      raise "Unable to remove task #{item.id} at priority #{item.priority} (no queue at that priority)" if queue.nil?
      priority_decreased, original_priority, item = remove_item_from_queue(queue, item)
      if queue.empty?
        remove(queue, original_priority)
        @items.delete(queue.id)
      elsif priority_decreased
        remove(queue, original_priority)
        push(queue)
      end
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
    
    def remove_item_from_queue(queue, target_item)
      original_priority = queue.priority
      
      if target_item == :next
        item = queue.next_item
      else
        item = queue.remove_item(target_item)
      end
       
      if queue.priority.nil? || original_priority < queue.priority
        return [true, original_priority, item]
      end
      [false, original_priority, item]
    end
    
    def get_queue(queue_id, create)
      queue =  @items[queue_id]
      return [true, queue] unless queue.nil?
      return [false, nil] unless create
      queue = create_queue(queue_id) #BackgroundQueue::ServerLib::Owner.new(owner_id)
      @items[queue_id] = queue
      return [false, queue]
    end
    
  end
end
