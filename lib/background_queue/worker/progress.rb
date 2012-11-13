module BackgroundQueue::Worker
  #a way of notifying worker progress
  class Progress
    
    attr_reader :registered_tasks
  
    def initialize(callback_object)
      if callback_object.kind_of?(BackgroundQueue::Worker::Base)
        @worker = callback_object
      elsif callback_object.kind_of?(Proc) 
        @callback = callback_object
      else
        @callback_object = callback_object
      end  
      
      @main_caption = nil
      @sub_caption = nil
      
      @finished_sub_progress = 0    
      @current_sub_progress_size = 0
      @current_sub_progress = 0
      @sub_task_step_size = 0
    end
    
    def start(main_caption=nil)
      @main_caption = main_caption
 
      @sub_caption = nil
      
      @finished_sub_progress = 0    
      @current_sub_progress_size = 0
      @current_sub_progress = 0

      update_callback
    end
    
    def set_main_caption(caption)
      @main_caption = caption
      update_callback
    end
    
    def finish(main_caption = nil)
      @main_caption = main_caption unless main_caption.nil?
      @sub_caption = nil unless main_caption.nil?
      @current_sub_progress = 0
      @finished_sub_progress = 100
      update_callback
    end
    
    
    def register_task(key, units)
      @registered_tasks ||= {}
      @registered_task_total ||= 0
      @registered_tasks[key] = units
      @registered_task_total += units
    end
    
    def start_task(key, caption=nil)
      if @current_sub_progress_size != 0
        @finished_sub_progress += @current_sub_progress_size
        @current_sub_progress_size = 0
      end
      @current_sub_progress_size = get_task_size(key)
      @current_sub_progress = 0.0
      @sub_task_step_size = 0
      @sub_caption = caption
      update_callback
    end
    
    def get_task_size(key)
      raise "No registered sub task (#{key})" if @registered_tasks[key].nil?
      @registered_tasks[key].to_f / @registered_task_total * 100.0
    end
    
    def set_task_steps(step_count)
      if step_count == 0
        @sub_task_step_size = 100
      else
        @sub_task_step_size = 100.0 / step_count.to_f * 100.0
      end
    end
    
    def inc
      @current_sub_progress += @sub_task_step_size 
      update_callback
    end
    
    def set_task_progress(percent)
      @current_sub_progress += percent
      @current_sub_progress = 100 if @current_sub_progress > 100
      update_callback
    end   
    
    def set_task_caption(caption)
      @sub_caption = caption
      update_callback
    end
    
    def add_note(notice)
      update_callback_meta(:notice, notice)
    end
    
    def add_warning(warning)
      update_callback_meta(:warning, warning)
    end
    
    def add_error(error)
      update_callback_meta(:error, error)
    end
    
    def set_meta_data(key, data)
      update_callback_meta(:meta, {key=>data})
    end
    
    def get_caption
      if @main_caption && @sub_caption 
        "#{@main_caption}: #{@sub_caption }"
      elsif @main_caption
        @main_caption
      elsif @sub_caption 
        @sub_caption 
      else
        ""
      end
    end
    
    def get_percent
      @finished_sub_progress + (@current_sub_progress_size  / 100.0 * @current_sub_progress / 100.0)
    end
    
    def update_callback
      if @worker
        @worker.set_progress(get_caption, get_percent)
      elsif @callback
        @callback.call(:progress, get_caption, get_percent)
      elsif @callback_object
        @callback_object.set_progress(get_caption, get_percent, self)
      end
    end
    
    def update_callback_meta(key, value)
      if @worker
        @worker.add_progress_meta(key, value)
      elsif @callback
        @callback.call(:meta, key, value)
      elsif @callback_object
        @callback_object.add_progress_meta(key, value, self)
      end
    end
    
  end
end
