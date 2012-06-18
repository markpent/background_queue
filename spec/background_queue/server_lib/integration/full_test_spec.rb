require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')
require 'background_queue_server'
require 'background_queue'
require 'net/http'

require 'rubygems'
gem "rufus-scheduler"

#unless defined? Rails
  module Rails; 
    def self.env
      "development"
    end
  end
#end

describe "Full Test" do

  context "simple task" do
  
    it "will call worker server" do

      config_path = File.expand_path(File.dirname(__FILE__) + '/../../../resources/config.yml')
      
      server = BackgroundQueue::ServerLib::Server.new

      thread = Thread.new {
        server.start(:config=>config_path, :skip_pid=>true, :command=>:run, :log_file=>"/tmp/bq.log", :log_level=>'debug')
      }

      while server.event_server.nil? || !server.event_server.running
        sleep(0.1)
      end

      meth_name = nil
      ss = TestWorkerServer.new(8001)
      ss.start(Proc.new { |request, response|
        meth_name = request.request_method

        response.status = 200
        response['Content-Type'] = "text/text"
        response.body = "{percent:100, caption:'Done'}"
      })
      
      
      client_config_path = File.expand_path(File.dirname(__FILE__) + '/../../../resources/config-client.yml')
      
      client = BackgroundQueue::Client.new(client_config_path)
      

      client.add_task(:some_worker, :owner_id, :job_id, :task_id, {:something=>:else}, {:domain=>"www.example.com"} )

      ss.wait_to_be_called.should be_true


      meth_name.should eq("POST")
      ss.stop

      server.stop

    end
    
    
    
  end
end
