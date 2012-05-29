module BackgroundQueue::ServerLib
  #internally implemented using a list of queues
  #this does not do any locking, subclasses should look after any locking
  class PriorityQueue
  
    def initialize
      @queues = []
      @items = {}
      @stalled_items = {}
      @stalled = false
    end
    
    def pop
      q = get_next_queue
      return nil if q.nil?
      item = q.shift
      if q.empty?
        remove_queue(q)
      end
      item
    end
    
    def push(item)
      q = get_queue_for_priority(item.priority, true)
      q.push(item)
    end
    
    def remove(item, override_priority=nil)
      override_priority = item.priority if override_priority.nil?
      q = get_queue_for_priority(override_priority, false)
      raise "unable to get queue at priority #{override_priority} when removing" if q.nil?
      q.delete_if { |q_item| q_item.id == item.id }
      if q.empty?
        remove_queue(q)
      end
    end
    
    #the highest priority queue
    def priority
      return nil if @queues.empty?
      get_next_queue.priority
    end
    
    def stalled?
      @stalled
    end
    
    def stalled=(stall)
      @stalled = stall
    end
    
    def empty?
      @queues.empty?
    end
    
    def number_of_priorities
      @queues.length
    end
    
    def number_if_items_at_priority(priority)
      q = get_queue_for_priority(priority, false)
      return 0 if q.nil?
      q.length
    end
    
    def peek
      q = get_next_queue
      return nil if q.nil?
      q.first
    end
    
    private
    
    def get_queue_for_priority(priority, create)
      @queues.each_with_index do |q, idx|
        return q if q.priority == priority
        if q.priority > priority #passed it.. insert here...
          return nil unless create
          return insert_queue_at_index(priority, idx)
        end
      end
      return insert_queue_at_index(priority, -1)
    end
    
    def insert_queue_at_index(priority, index)
      q = PriorityArray.new(priority)
      @queues.insert(index, q)
      q
    end
    
    def get_next_queue
      @queues.first
    end
    
    def remove_queue(queue)
      @queues.delete(queue)
    end
    
    def get_queues
      @queues
    end
  end
  
  
  #this is an array with a priority attribute
  class PriorityArray < Array
    
    attr_accessor :priority
    def initialize(priority)
      @priority = priority
      super(0)
    end
    
    def ==(other)
      other.priority == self.priority
    end
    
    def inspect
      "#{self.priority}:#{super}"
    end
  end
end


#balanced_queue => owners => jobs => items
#items can change owner/jobs
#balanced_queue, and owner are priority queues
#job is a normal queue
#as an item is popped from the queue, its priority is recalculated

#bq.next_task gets pops owner with highest priority. Calls owner.next_task(). If no tasks, will wait()
  #owner.next_task pops next job with highest priority. Calls job.next_task
    #job.next_task pops next task with highest priority
  #job is added back to owner with current priority (unless empty?). Task is returned
#owner is added back to bq with current priority (unless empty?), Task is returned
  
#task is run()
  #mark task as running
  #call http to call the worker
  #deregister task if run_version is the same (run_version is incremented each time the same task is reregistered)
  
  
  #task registry keeps track of items so they can be found/re-inserted
  #the queue keeps track of all items using hashes until item is removed (not popped)
  #this allows a get(id) method and a pop() method
  #get will add an instance to the hash if not found
  
    
