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
    
    attr_reader :total_weighted_tasks
    attr_reader :total_weighted_percent
    attr_reader :completed_weighted_percent
    attr_reader :completed_weighted_tasks
    attr_reader :running_percent_weighted
    
    attr_reader :summary
    
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
      @total_weighted_tasks = 0
      @total_weighted_percent = 0.0
      @completed_weighted_percent = 0.0
      @completed_weighted_tasks = 0
      @running_percent_weighted = 0.0
      @status_meta = {}
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
    
    def server
      @owner.server
    end

    def add_item(task)
      task.set_job(self)
      @total_tasks += 1
      unless task.is_excluded_from_count?
        @total_counted_tasks += 1
      end
      if task.weighted?
        @total_weighted_tasks += 1
        @total_weighted_percent += task.weighted_percent
      end
      #@synchronous_count+=1 if task.synchronous? #the queue only goes into sync mode once the task is running/about to run
      unless task.initial_progress_caption.nil? || task.initial_progress_caption.length == 0 || @current_progress[:percent] > 0
        @current_progress[:caption] = task.initial_progress_caption
      end
      push(task)
    end
    
    def next_item
      item = pop
      @running_items += 1 if item
      @synchronous_count+=1 if item && item.synchronous?
      item
    end
    
    def remove_item(item)
      remove(item)
    end
    
    def finish_item(item)
      @running_items -= 1
      @synchronous_count-=1 if item.synchronous?
    end
    
    def synchronous?
      next_item = peek
      @synchronous_count > 0 || (next_item && next_item.synchronous?)
    end
    
    def set_worker_status(status)
      if status[:meta]
        update_status_meta(status[:meta])
      elsif status[:summary]
        update_summary_meta(status)
      else
        running_status = get_running_status(status)
        if status[:percent] >= 100
          update_finished_status(status)
        else
          update_running_status(running_status, status)
        end
      end
    end
    
    def get_running_status(status)
      rstatus = @running_status[status[:task_id]]
      rstatus = register_running_status(status) if rstatus.nil?
      rstatus
    end
    
    def register_running_status(status)
      rstatus = {:task_id=>status[:task_id], :caption=>status[:caption], :percent=>0, :exclude=>status[:exclude], :weight=>status[:weight] }
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
      unless rstatus.nil?
        @running_ordered_status.delete(rstatus) 
      end
      rstatus
    end
    
    def update_running_status(running_status, status)
      running_status[:percent] = status[:percent]
      running_status[:caption] = status[:caption]
      update_running_percent
    end
    
    
    def update_status_meta(meta)
      [:notice, :warning, :error].each { |key|
        if meta[key]
          @status_meta[key] = [] if @status_meta[key].nil?
          @status_meta[key] << meta[key]
        end
      }
      if meta[:meta]
        @status_meta[:meta] = {} if @status_meta[:meta].nil?
        @status_meta[:meta] = @status_meta[:meta].update(meta[:meta])
      end
      update_current_progress
    end
    
    def update_summary_meta(status)
      @summary ||= {}
      type = status[:type].intern
      case status[:summary]
      when "app"
        @summary[type] ||= []
        @summary[type] << status[:data]
      when "set"
        @summary[type] ||= {}
        @summary[type][status[:key]] = status[:data]
      when "inc"
        @summary[type] ||= 0
        @summary[type] += status[:data].to_i
      when "dec"
        @summary[type] ||= 0
        @summary[type] -= status[:data].to_i
      when "res"
        if type == :all
          @summary = {}
        else
          @summary.delete(type)
        end
      else
        logger.error("Unknown summary action: #{status[:summary]}")
      end
    end
    
    def update_finished_status(status)
      rstatus = deregister_running_status(status[:task_id])
      unless rstatus.nil?
        @completed_tasks += 1
        @completed_counted_tasks += 1 unless rstatus[:exclude]
        unless rstatus[:weight].nil?
          @completed_weighted_percent += rstatus[:weight] 
          @completed_weighted_tasks += 1
        end
        if self.current_running_status.nil? || @current_running_status == rstatus
          #sometimes the status is finished straight away...
          update_current_caption(status)
        end
        update_running_percent()
      end
    end
    
    def update_running_percent
      total_percent = 0.0
      total_task_percent = 0.0
      total_percent_counted = 0.0
      total_weighted_percent = 0.0
      for status in @running_ordered_status
        if status[:weight] && status[:weight] > 0
          total_weighted_percent += (status[:percent] * status[:weight] / 100.0)
        else
          total_percent_counted += status[:percent] unless status[:exclude]
          total_percent += status[:percent]
        end
        total_task_percent += status[:percent]
      end
      set_running_percent(total_percent_counted.to_f / 100.0, total_percent.to_f / 100.0, total_task_percent / 100.0, total_weighted_percent.to_f / 100.0)
      self.update_current_progress
    end
    
    def set_running_percent(pcent_counted, pcent, running_task_pcent, weighted_percent)
      @running_percent_counted = pcent_counted
      @running_percent = pcent
      @running_percent_weighted = weighted_percent
      idx = running_task_pcent.to_i
      if @running_ordered_status.length <= idx
        @current_running_status = @running_ordered_status.last
      else
        @current_running_status = @running_ordered_status[idx]
      end
    end
    
    def get_current_progress_percent
      unweighted_percent = (100.0 - self.total_weighted_percent) / 100.0

      total_unweighted_tasks = self.total_tasks - self.total_weighted_tasks
      completed_unweighted_tasks = self.completed_tasks - self.completed_weighted_tasks
      total_finished_percent = total_unweighted_tasks == 0 ? 0 : (completed_unweighted_tasks.to_f / total_unweighted_tasks.to_f) * 100.0 
      running_fraction = total_unweighted_tasks == 0 ?  1.0 : (1.0 / total_unweighted_tasks.to_f)
      
      
      total_running_percent = self.running_percent.to_f * running_fraction * 100.0 
      
      total_unweighted_percent = (total_finished_percent + total_running_percent) * unweighted_percent
      
      total_percent = total_unweighted_percent.to_f + (running_percent_weighted * 100.0) + completed_weighted_percent
      
      total_percent
    end
    
    def get_current_progress_caption
      if self.current_running_status
        update_current_caption(self.current_running_status)
      end
      @current_caption
    end
    
    def update_current_caption(status)
      caption = status[:caption]
      caption = "" if caption.nil?
      if total_counted_tasks > 1 && status[:exclude] != true
        caption = "#{caption} (#{self.get_current_counted_tasks}/#{self.total_counted_tasks})"
      end
      @current_caption = caption
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
      }.update(@status_meta)
      #puts "set status to #{@current_progress.inspect}"
    end

    def get_current_progress
      @current_progress
    end
    
   
  end
end
