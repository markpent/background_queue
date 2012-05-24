require 'net/http'
require 'json'

module BackgroundQueue::ServerLib
  class WorkerClient
    def initialize(server)
      @server = server
    end
    
    def build_request(uri, task, auth)
      @uri = URI(uri)
      req = Net::HTTP::Post.new(@uri.path)
      req.set_form_data({:task=>task.to_json, :auth=>auth})
      req["host"] = task.domain
      req
    end
    
    def send_request(worker_config, task, auth)
      @current_task = task
      req = build_request(worker_config.url, task, auth)
      begin
        Net::HTTP.start(worker_config.uri.host, worker_config.uri.port) do |server|
          server.request(req) do |response|
            read_response(response, task)
          end
        end
      rescue Exception=>e
        return false
      end
    end
    
    def read_response(http_response, task)
      if http_response.code == "200"
        http_response.read_body do |chunk|
          process_chunk(chunk, task)
        end
      else
        raise "Invalid response code: #{http_response.code}"
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
        #silently fail (TODO: log this!)
        #puts e.message
        false
      end
    end
    
    def set_worker_status(status, task)
      status_map = BackgroundQueue::Utils::AnyKeyHash.new(status)
      task.set_worker_status(status_map)
    end
    
  end
end
