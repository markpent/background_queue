require 'net/http'
require 'json'

module BackgroundQueue::ServerLib
  #The client to a worker.
  #Use http to connect to the worker, send the command, and process the streamed response of json encoded status updates.
  class WorkerClient
    def initialize(server)
      @server = server
    end
    
    #send a request to the specified worker, passing the task and authenticating using the secret
    def send_request(worker, task, secret)
      @current_task = task
      req = build_request(worker.uri, task, secret)
      begin
        Net::HTTP.start(worker.uri.host, worker.uri.port) do |server|
          server.request(req) do |response|
            read_response(worker, response, task)
          end
        end
        true
      rescue Exception=>e
        @server.logger.error("Error sending request #{task.id} to worker: #{e.message}")
        @server.logger.debug(e.backtrace.join("\n"))
        return false
      end
    end
    
    private
    
    def build_request(uri, task, secret)
      req = Net::HTTP::Post.new(uri.path)
      req.set_form_data({:task=>task.to_json, :auth=>secret})
      req["host"] = task.domain
      req
    end
    
    
    
    def read_response(worker, http_response, task)
      if http_response.code == "200"
        http_response.read_body do |chunk|
          process_chunk(chunk, task)
        end
      else
        raise "Invalid response code (#{http_response.code}) when calling #{worker.uri.to_s}"
      end
    end
    
    def process_chunk(chunk, task)
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
        set_worker_status(hash_data, task)
        true
      rescue Exception=>e
        @server.logger.error("Error processing status line of task #{task.id}: #{e.message}")
        @server.logger.debug(e.backtrace.join("\n"))
        false
      end
    end
    
    def set_worker_status(status, task)
      status_map = BackgroundQueue::Utils::AnyKeyHash.new(status)
      task.set_worker_status(status_map)
    end
    
  end
end
