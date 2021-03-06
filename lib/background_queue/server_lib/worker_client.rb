require 'net/http'
require 'json'

module BackgroundQueue::ServerLib
  #The client to a worker.
  #Use http to connect to the worker, send the command, and process the streamed response of json encoded status updates.
  class WorkerClient
    def initialize(server)
      @server = server
      @has_received_finish = false
    end
    
    #send a request to the specified worker, passing the task and authenticating using the secret
    def send_request(worker, task, secret)
      @current_task = task
      req = build_request(worker.uri, task, secret)
      begin
        http_client = build_http_client(worker)
        http_client.read_timeout = 86400
        http_client.start do |server|
          server.request(req) do |response|
            read_response(worker, response, task)
          end
        end
        if has_received_finish?
          return :ok
        else
          @server.logger.debug("WorkerClient.send_request: !has_received_finish?")
          return :worker_error
        end
      rescue BackgroundQueue::ServerLib::WorkerError => we
        @server.logger.error("Worker Error sending request #{task.id} to worker: #{we.message}")
        return :worker_error
      rescue Timeout::Error => te
        @server.logger.error("Worker Error sending request #{task.id} to worker: #{te.message}")
        return :worker_error
      rescue BackgroundQueue::ServerLib::ThreadManager::ForcedStop => fe
        @server.logger.error("Thread stop while sending request #{task.id} to worker: #{fe.message}")
        return :stop
      rescue Exception=>e
        @server.logger.error("Error sending request #{task.id} to worker: #{e.class.name}:#{e.message}")
        @server.logger.debug(e.backtrace.join("\n"))
        return :fatal_error
      end
    end
    
    private
    
    def build_http_client(worker)
      Net::HTTP.new(worker.uri.host, worker.uri.port)
    end
    
    def build_request(uri, task, secret)
      req = Net::HTTP::Post.new(uri.path)
      form_data = {:task=>task.to_json, :auth=>secret, :server_port=>@server.config.address.port}
      form_data[:summary] = task.get_job.summary.to_json if task.send_summary? && !task.get_job.summary.nil?
      form_data[:step] = task.step unless task.step.nil?
      req.set_form_data(form_data)
      if task.domain.nil?
        fallback_domain = BackgroundQueue::Utils.get_hash_entry(@server.config.system_task_options, :domain)
        req["host"] = fallback_domain unless fallback_domain.nil?
      else
        req["host"] = task.domain
      end
      req
    end
    
    def read_response(worker, http_response, task)
      if http_response.code == "200"
        http_response.read_body do |chunk|
          process_chunk(chunk, task)
        end
        #the last chunk did not end in a newline... process it
        unless @prev_chunk.nil?
          process_line(@prev_chunk.strip, task)
          @prev_chunk = nil
        end
      else
        raise BackgroundQueue::ServerLib::WorkerError, "Invalid response code (#{http_response.code}) when calling #{worker.uri.to_s}"
      end
    end
    
    def process_chunk(chunk, task)
      #puts "process_chunk: #{chunk}"
      chunk.each_line do |line|
        unless @prev_chunk.nil?
          line = @prev_chunk + line
          @prev_chunk = nil
        end
        if line[-1,1] == "\n" #it ends in a newline so its a complete line
          process_line(line.strip, task)
        else
          @prev_chunk = line
        end
      end
    end
    
    def process_line(line, task)
      hash_data = nil
      begin
        hash_data = JSON.load(line)
        if hash_data.kind_of?(Hash)
          set_worker_status(hash_data, task)
        else
          raise "Invalid Status Line (wrong datatype: #{hash_data.class.name}"
        end
        true
      rescue BackgroundQueue::ServerLib::WorkerError=>we
        raise we
      rescue Exception=>e
        @server.logger.error("Error processing status line of task #{task.id}: #{e.message}")
        @server.logger.debug(e.backtrace.join("\n"))
        false
      end
    end
    
    def set_worker_status(status, task)
      begin
        status_map = BackgroundQueue::Utils::AnyKeyHash.new(status)
        if status_map[:finished] == true
          set_has_received_finish
        elsif status_map[:error]
          raise BackgroundQueue::ServerLib::WorkerError, "Fatal error from worker: #{status_map[:error]}"
        else
          task.set_worker_status(status_map)
        end
      rescue BackgroundQueue::ServerLib::WorkerError=>we
        raise we
      rescue Exception=>e
        @server.logger.error("Error setting status for task #{task.id} using status #{status.inspect}: #{e.message}")
        @server.logger.error(e.backtrace.join("\n"))
      end
    end
    
    def has_received_finish?
      @has_received_finish
    end
    
    def set_has_received_finish
      @has_received_finish = true
    end
    
  end
  
  class WorkerError < Exception
    
  end
end
