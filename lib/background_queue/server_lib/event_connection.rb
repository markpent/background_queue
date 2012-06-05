require 'eventmachine'

module BackgroundQueue::ServerLib
  class EventConnection < EventMachine::Connection
    
    attr_accessor :server
    
    STAGE_LENGTH = 0
    STAGE_BODY = 1
    
    MAX_BODY_LENGTH = 9999999
    
    
    def post_init
      @data = ""
      @length = 0
      @stage = STAGE_LENGTH
    end
    
    def receive_data(data)
      @data << data
      if @stage == STAGE_LENGTH
        if @data.length >= 6
          s_header = @data.slice!(0,6)
          version, length = s_header.unpack("SL")
          
          if version == 1
            @length = length
            @stage = STAGE_BODY
            if length > MAX_BODY_LENGTH || length <= 0
              raise "Invalid length: #{length}"
            end
          else
            raise "Invalid header version: #{version}"
          end
        end
      end
      
      if @stage == STAGE_BODY && @data.length == @length
        #body received
        process_data(@data)
      end
    end
    
    def process_data(data)
      begin
        cmd = BackgroundQueue::Command.from_buf(data)
        result = process_command(cmd)
        send_result(result)
      rescue Exception=>e
        send_error(e.message)
      end
    end
    
    def send_result(command) 
      send(command.to_buf)
    end
    
    def send_error(message)
      send_result(build_simple_command(:error, message))
    end
    
    def build_simple_command(type, message)
      BackgroundQueue::Command.new(type, {}, {:message=>message})
    end
    
    def send(data)
      data_with_header = [1, data.length, data].pack("SLZ#{data.length}")
      send_data(data_with_header)
    end
    
    def process_command(command)
      case command.code
      when 'add_task' 
        process_add_task_command(command)
      when 'add_tasks'
        process_add_tasks_command(command)
      when 'remove_tasks'
        process_remove_tasks_command(command)
      else
        raise "Unknown command: #{command.code}"
      end
    end
    
    def process_add_task_command(command)
      task = BackgroundQueue::ServerLib::Task.new(command.args[:owner_id], command.args[:job_id], command.args[:task_id], command.args[:priority], command.args[:params], command.options)
      server.task_queue.add_task(task)
      build_simple_command(:result, "ok")
    end
    
    def process_add_tasks_command(command)
      shared_params = command.args[:shared_parameters]
      shared_params = {} if shared_params.nil?
      owner_id = command.args[:owner_id]
      job_id = command.args[:job_id]
      priority = command.args[:priority]
      for task_data in command.args[:tasks]
        if task_data[1].nil?
          merged_params = shared_params
        else
          merged_params = shared_params.clone.update(task_data[1])
        end
        task = BackgroundQueue::ServerLib::Task.new(owner_id, job_id, task_data[0], priority, merged_params, command.options)
        server.task_queue.add_task(task)
      end
      build_simple_command(:result, "ok")
    end
  
  end
end
