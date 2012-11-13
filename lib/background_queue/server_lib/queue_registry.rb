module BackgroundQueue::ServerLib
  module QueueRegistry
  
    def add_item(item)
      in_queue, queue = get_queue(get_queue_id_from_item(item), true)
      priority_increased, original_priority = track_priority_when_adding_to_queue(queue, item)
      if !queue.stalled? && (!in_queue || priority_increased)
        if in_queue #remove from existing priority queue
          remove(queue, original_priority)
        end
        push(queue)
      elsif queue.stalled? && !(queue.synchronous? && queue.has_running_items?) #it stalled because it was empty...
        resume_queue(queue)
      end
    end
    
    def next_item
      item = nil
      queue = pop
      unless queue.nil?
        priority_decreased, original_priority, item = remove_item_from_queue(queue, :next)
        
        # some items must run synchronously, so we dont want to add it back until the task is finished.
        # if the queue it empty we still want to keep it there until the task is finished, incase the running task queues more tasks against the job.
        if queue.empty? || queue.synchronous?
          @items.delete(queue.id) 
          stall_queue(queue)
        else
          push(queue)
        end
        @running_items += 1
        item.running = true unless item.nil?
      end
      #server.logger.debug("next item #{item.nil? ? 'nil' : item.id}")
      item
    end
    
    def remove_item(item)
      item.running = false
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
    
    def finish_item(item)
      #puts "#{self.class.name}:finish item: #{item.inspect}"
      in_queue, queue = get_queue(get_queue_id_from_item(item), false)
      raise "Queue #{get_queue_id_from_item(item)} unavailble when finishing item" if queue.nil?
      queue.finish_item(item)
      @running_items -= 1
      resume_queue(queue) unless queue.synchronous? && queue.has_running_items?
    end
    
    private
    
    def create_queue(queue_id)
      self.class.queue_class.new(queue_id, self)
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
      queue = @stalled_items[queue_id] if queue.nil?
      return [true, queue] unless queue.nil?
      return [false, nil] unless create
      queue = create_queue(queue_id) #BackgroundQueue::ServerLib::Owner.new(owner_id)
      @items[queue_id] = queue
      return [false, queue]
    end
    
    def stall_queue(queue)
      queue.stalled = true
      server.logger.debug("stalling queue #{queue.id} (empty=#{queue.empty?})")
      #puts "stalling queue #{queue.inspect}"
      @stalled_items[queue.id] = queue
    end
    
    def resume_queue(queue)
      if queue.stalled?
        
        if queue.empty? && !queue.has_running_items?
          @stalled_items.delete(queue.id) 
          @items.delete(queue.id)
          server.logger.debug("removed empty queue #{queue.id}")
          #puts "q empty"
        elsif !queue.empty?
          @stalled_items.delete(queue.id) 
          queue.stalled = false
          push(queue)
          @items[queue.id] = queue
          server.logger.debug("resumed queue #{queue.id}")
          #puts "returned q: #{queue.inspect}"
        else
          server.logger.debug("keeping empty queue stalled #{queue.id}")
          #keep stalled
        end
      #else
      #  puts "q not stalled"
      end
    end
    
    def stalled_items
      @stalled_items
    end
    
  end
end
