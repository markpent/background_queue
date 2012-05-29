module BackgroundQueue::ServerLib
  class Job < PriorityQueue
  
    attr_accessor :id
    attr_reader :running_status
    attr_reader :running_ordered_status
    attr_reader :total_tasks
    attr_reader :total_counted_tasks
    attr_reader :completed_tasks
    attr_reader :completed_counted_tasks
    attr_reader :running_percent
    attr_reader :running_percent_counted
    attr_reader :current_running_status
    #attr_reader :current_running_excluded_status
    
    def initialize(id, owner)
      @id = id
      @owner = owner
      @stalled = false
      @total_tasks = 0
      @total_counted_tasks = 0
      @completed_tasks = 0
      @completed_counted_tasks = 0
      @running_status = {}
      @running_ordered_status = []
      @running_percent = 0
      @current_running_status = nil
      @current_progress = {:percent=>0.0, :caption=>""}
      @current_caption = ""
      @synchronous_count = 0
      @mutex = Mutex.new
      #@current_running_excluded_status = nil
      super()
    end

    def ==(other)
      @id == other.id
    end
    
    def inspect
      "#{self.id}:#{@queues.inspect}"
    end

    def add_item(task)
      task.set_job(self)
      @total_tasks += 1
      unless task.is_excluded_from_count?
        @total_counted_tasks += 1
      end
      @synchronous_count+=1 if task.synchronous?
      push(task)
    end
    
    def next_item
      pop
    end
    
    def finish_item(item)
      @synchronous_count-=1 if item.synchronous?
    end
    
    def synchronous?
      @synchronous_count > 0
    end
    
    
    
    def set_worker_status(status)
      if status[:percent] >= 100
        update_finished_status(status)
      else
        running_status = get_running_status(status)
        update_running_status(running_status, status)
      end
    end
    
    def get_running_status(status)
      rstatus = @running_status[status[:task_id]]
      rstatus = register_running_status(status) if rstatus.nil?
      rstatus
    end
    
    def register_running_status(status)
      rstatus = {:task_id=>status[:task_id], :caption=>status[:caption], :percent=>0, :exclude=>status[:exclude] }
      @running_status[status[:task_id]] = rstatus
      #if status[:exclude]
      #  @current_running_excluded_status = rstatus
      #else
        @running_ordered_status << rstatus 
      #end
      rstatus
    end
    
    def deregister_running_status(task_id)
      rstatus = @running_status.delete(task_id)
      @running_ordered_status.delete(rstatus) unless rstatus.nil?
      rstatus
    end
    
    def update_running_status(running_status, status)
      running_status[:percent] = status[:percent]
      running_status[:caption] = status[:caption]
      update_running_percent
    end
    
    
    def update_finished_status(status)
      rstatus = deregister_running_status(status[:task_id])
      unless rstatus.nil?
        @completed_tasks += 1
        @completed_counted_tasks += 1 unless rstatus[:exclude]
       # @current_running_excluded_status = nil if @current_running_excluded_status == rstatus
        update_running_percent()
      end
    end
    
    def update_running_percent
      total_percent = 0.0
      total_percent_counted = 0.0
      for status in @running_ordered_status
        total_percent_counted += status[:percent] unless status[:exclude]
        total_percent += status[:percent]
      end
      set_running_percent(total_percent_counted.to_f / 100.0, total_percent.to_f / 100.0)
      
      self.update_current_progress
      
      
    end
    
    def set_running_percent(pcent_counted, pcent)
      @running_percent_counted = pcent_counted
      @running_percent = pcent
      idx = @running_percent.to_i
      #if idx == 0 && @running_ordered_status.length == 0 && !@current_running_excluded_status.nil?
      #  @current_running_status = @current_running_excluded_status
      if @running_ordered_status.length <= idx
        @current_running_status = @running_ordered_status.last
      else
        @current_running_status = @running_ordered_status[idx]
      end
    end
    
    def get_current_progress_percent
      total_finished_percent = self.total_tasks == 0 ? 0 : (self.completed_tasks.to_f / self.total_tasks.to_f) * 100.0
      running_fraction = self.total_tasks == 0 ?  1.0 : (1.0 / self.total_tasks.to_f)
      
      total_running_percent = self.running_percent.to_f * running_fraction * 100.0
      
      total_percent = total_finished_percent + total_running_percent
      
      total_percent
    end
    
    def get_current_progress_caption
      if self.current_running_status
        caption = self.current_running_status[:caption]
        caption = "" if caption.nil?
        if total_counted_tasks > 1 && self.current_running_status[:exclude] != true
          caption = "#{caption} (#{self.get_current_counted_tasks}/#{self.total_counted_tasks})"
        end
        @current_caption = caption
      end
      @current_caption
    end
    
    def get_current_counted_tasks
      cnt = self.completed_counted_tasks + self.running_percent_counted.to_i
      if cnt < self.total_counted_tasks
        cnt += 1
      end
      cnt
    end
    
    def update_current_progress
      @current_progress = {
        :percent=>get_current_progress_percent,
        :caption=>get_current_progress_caption
      }
    end

    def get_current_progress
      @current_progress
    end
    
   
  end
end
