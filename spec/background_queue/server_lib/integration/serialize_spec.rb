require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')
require 'background_queue_server'
require 'background_queue'
require 'background_queue_worker'
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

describe "Serialize Test" do

  context "saving running tasks" do
  
    it "will save running tasks" do

      File.delete("/tmp/bq_tasks") if File.exist?("/tmp/bq_tasks")

      config_path = File.expand_path(File.dirname(__FILE__) + '/../../../resources/config-serialize.yml')
      
      server = BackgroundQueue::ServerLib::Server.new

      thread = Thread.new {
        server.start(:config=>config_path, :skip_pid=>true, :command=>:run, :log_file=>"/tmp/bq.log", :log_level=>'debug')
      }

      while server.event_server.nil? || !server.event_server.running
        sleep(0.1)
      end
      
      stopped = false
      begin

        
        mutex = Mutex.new
        condvar = ConditionVariable.new
        called = false
        
        meth_name = nil
        ss = TestWorkerServer.new(8001)
        ss.start(Proc.new { |controller|
          meth_name = controller.request.request_method
          
          mutex.synchronize {
            called = true
            condvar.signal
          }
          sleep(10)
          controller.render :text => {:percent=>100, :caption=>"Not Done"}.to_json, :type=>"text/text"
        })
        
        
        client_config_path = File.expand_path(File.dirname(__FILE__) + '/../../../resources/config-client.yml')
        
        client = BackgroundQueue::Client.new(client_config_path)
        
  
        job_handle = client.add_task(:some_worker, :owner_id, :job_id, :task_id, 2, {:something=>:else}, {:domain=>"www.example.com"} )
        
        mutex.synchronize {
          unless called
            condvar.wait(mutex, 5)
          end
        }
        
        called.should be_true
        
        #the job is now running
        server.stop(0.1)
        thread.join
        ss.stop
        
        #lets make sure it can load back up and finish properly this time
        
        ss = TestWorkerServer.new(8001)
        ss.start(Proc.new { |controller|
          meth_name = controller.request.request_method
          
          mutex.synchronize {
            called = true
            condvar.signal
          }
          controller.render :text => {:percent=>100, :caption=>"Done"}.to_json, :type=>"text/text"
        })
        
        
        server = BackgroundQueue::ServerLib::Server.new

        thread = Thread.new {
          server.start(:config=>config_path, :skip_pid=>true, :command=>:run, :log_file=>"/tmp/bq.log", :log_level=>'debug')
        }
  
        while server.event_server.nil? || !server.event_server.running
          sleep(0.1)
        end
        
        stopped = false
        
        
        ss.wait_to_be_called.should be_true
        
        result = client.get_status(job_handle)
  
        result.code.should eq(:status)
        result.args[:percent].should eq(100)
        result.args[:caption].should eq('Done')
        
        ss.stop
      ensure
        unless stopped
          server.stop
          thread.join
        end
      end
    end
    
  end
  
end
