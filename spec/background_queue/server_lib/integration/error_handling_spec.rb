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

describe "Error Handling Test" do

  context "same task" do
  
    it "will add tasks to an error list" do

      
      config_path = File.expand_path(File.dirname(__FILE__) + '/../../../resources/config.yml')
      BackgroundQueue::Worker::Config.worker_path = File.expand_path(File.dirname(__FILE__) + '/../../../resources/')
      BackgroundQueue::Worker::Config.secret = "this_is_used_to_make_sure_it_is_secure"
      
      server = BackgroundQueue::ServerLib::Server.new

      thread = Thread.new {
        server.start(:config=>config_path, :skip_pid=>true, :command=>:run, :log_file=>"/tmp/bq.log", :log_level=>'debug')
      }

      while server.event_server.nil? || !server.event_server.running
        sleep(0.1)
      end
      ss = nil
      begin

        meth_name = nil
        
        
        
        client_config_path = File.expand_path(File.dirname(__FILE__) + '/../../../resources/config-client.yml')
        
        client = BackgroundQueue::Client.new(client_config_path)
        
  
        job_handle = client.add_task(:simple_worker, :owner_id, :job_id, :task_id, 2, {:something=>:else, :retry_limit=>2}, {:domain=>"www.example.com"} )
        
        #it should fail...
        sleep(0.5)
        ss = TestWorkerServer.new(8001)
        attempt_count = 0
        ss.start(Proc.new { |controller|
          controller.class.send(:include, BackgroundQueue::Worker::Calling)
          controller.run_worker({:some=>'context'})
            
          #meth_name = controller.request.request_method
          #controller.render :text=>{:percent=>100, :caption=>"Done"}.to_json, :type=>"text/text"  
        })
        #it should now retry...
        ss.wait_to_be_called.should be_true
        
        #add same task while in existing in error state
        job_handle = client.add_task(:simple_worker, :owner_id, :job_id, :task_id, 2, {:something=>:else}, {:domain=>"www.example.com"} )
        
        ss.wait_to_be_called.should be_true
        
        result = client.get_status(job_handle)
  
        result.code.should eq(:status)
        result.args[:percent].should eq(100)
        result.args[:caption].should eq('Done')
  
        
      ensure
        ss.stop unless ss.nil?
        server.stop
        
        thread.join
      end
    end
    
    it "will retry worker errors until threshold" do

      
      config_path = File.expand_path(File.dirname(__FILE__) + '/../../../resources/config.yml')
      BackgroundQueue::Worker::Config.worker_path = File.expand_path(File.dirname(__FILE__) + '/../../../resources/')
      BackgroundQueue::Worker::Config.secret = "this_is_used_to_make_sure_it_is_secure"
      
      server = BackgroundQueue::ServerLib::Server.new

      thread = Thread.new {
        server.start(:config=>config_path, :skip_pid=>true, :command=>:run, :log_file=>"/tmp/bq.log", :log_level=>'debug')
      }

      while server.event_server.nil? || !server.event_server.running
        sleep(0.1)
      end
      ss = nil
      begin

        meth_name = nil
        
        
        ss = TestWorkerServer.new(8001)
        attempt_count = 0
        ss.start(Proc.new { |controller|
          controller.class.send(:include, BackgroundQueue::Worker::Calling)
          controller.run_worker({:callback=>Proc.new { |worker|
            attempt_count += 1
            if attempt_count == 3
              worker.set_progress("Done", 100)
            else
              raise "Some Error"
            end
          }})  
        })
        
        
        client_config_path = File.expand_path(File.dirname(__FILE__) + '/../../../resources/config-client.yml')
        
        client = BackgroundQueue::Client.new(client_config_path)
        
  
        job_handle = client.add_task(:callback_worker, :owner_id, :job_id, :task_id, 2, {}, {:domain=>"www.example.com", :retry_limit=>3} )
        
        #it should now retry...
        ss.wait_to_be_called.should be_true
        result = client.get_status(job_handle)
        result.code.should eq(:status)
        result.args[:percent].should eq(0)
        #attempt 2
        ss.wait_to_be_called.should be_true
        result = client.get_status(job_handle)
        result.code.should eq(:status)
        result.args[:percent].should eq(0)
        #attempt 3 (should pass)
        ss.wait_to_be_called.should be_true
        result = client.get_status(job_handle)
        result.code.should eq(:status)
        result.args[:percent].should eq(100)
        result.args[:caption].should eq('Done')

      ensure
        ss.stop unless ss.nil?
        server.stop
        
        thread.join
      end
    end
    
  end
  
end
