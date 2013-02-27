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

describe "Full Test" do

  context "simple task" do
  
    it "will call worker server" do

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
      
      begin

        meth_name = nil
        ss = TestWorkerServer.new(8001)
        ss.start(Proc.new { |controller|
          meth_name = controller.request.request_method
          controller.class.send(:include, BackgroundQueue::Worker::Calling)
          controller.run_worker({:some=>'context'})
          
          #controller.render :text => lambda { |response,output| 
          #  output.write({:percent=>100, :caption=>"Done"}.to_json)
          #}, :type=>"text/text"
          #controller.render :text=>, :type=>"text/text"
        })
        
        
        client_config_path = File.expand_path(File.dirname(__FILE__) + '/../../../resources/config-client.yml')
        
        client = BackgroundQueue::Client.new(client_config_path)
        
  
        job_handle = client.add_task(:simple_worker, :owner_id, :job_id, :task_id, 2, {:something=>:else}, {:domain=>"www.example.com"} )
        
        
        ss.wait_to_be_called.should be_true
        
        result = client.get_status(job_handle)
  
        result.code.should eq(:status)
        result.args[:percent].should eq(100)
        result.args[:caption].should eq('Done')
  
        meth_name.should eq("POST")
        ss.stop
      ensure
        server.stop
        
        thread.join
      end
    end
    
  end
  
  context "init task" do
    it "will spawn more tasks" do
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

        task_pos = 0
        
  
        
        client_config_path = File.expand_path(File.dirname(__FILE__) + '/../../../resources/config-client.yml')
        
        client = BackgroundQueue::Client.new(client_config_path)
        
        meth_name = nil
        ss = TestWorkerServer.new(8001, true)
        ss.start(Proc.new { |controller|
          #puts "worker called"
          meth_name = controller.request.request_method 
          if task_pos == 0
            task_pos += 1
            #puts "Adding more tasks"
            client2 = BackgroundQueue::Client.new(client_config_path)
            result2, server_used2 = client.add_tasks(:callback_worker, :owner_id, :job_id, [[:task1_id, {:a=>:b}], [:task2_id, {:e=>:f}]], 2, {:something=>:else}, {:domain=>"www.example.com"} )
          end
          controller.render :text=>{:percent=>100, :caption=>"Done"}.to_json + "\n" + {:finished=>true}.to_json, :type=>"text/text"
        })
        
        
        
        job_handle = client.add_task(:callback_worker, :owner_id, :job_id, :task_id, 2, {:something=>:else}, {:domain=>"www.example.com", :weight=>20.0, :exclude=>true, :initial_progress_caption=>"Loading" } )
        
        result = client.get_status(job_handle )
  
        #puts "test1"
        result.code.should eq(:status)
        result.args[:percent].should eq(0.0)
        result.args[:caption].should eq('Loading')
        
        
        stats = client.get_stats(job_handle.server)
        stats[:running].should eq(1)
  
  
        
        ss.allow_to_be_called
  
        ss.wait_to_be_called.should be_true
  
        
        result = client.get_status(job_handle )
  
        #puts "test1"
        result.code.should eq(:status)
        result.args[:percent].should eq(20.0)
        result.args[:caption].should eq('Done')
  
        meth_name.should eq("POST")
        
        stats = client.get_stats(job_handle.server)
        stats[:running].should eq(2)   
        stats[:run_tasks].should eq(1)
        
        #pp server
        
        ss.allow_to_be_called
        ss.wait_to_be_called.should be_true
        
        result = client.get_status(job_handle )
  
        #puts "test2"
        result.code.should eq(:status)
        result.args[:percent].should eq(60.0)
        result.args[:caption].should eq('Done (2/2)')
        
        
        ss.allow_to_be_called
        ss.wait_to_be_called.should be_true
        
        result = client.get_status(job_handle )
  
        #puts "test3"
        result.code.should eq(:status)
        result.args[:percent].should eq(100.0)
        result.args[:caption].should eq('Done (2/2)')
        
        stats = client.get_stats(job_handle.server)
        stats[:tasks].should eq(0) 
        stats[:running].should eq(0)   
        stats[:run_tasks].should eq(3)
        
        
      ensure
        ss.stop unless ss.nil?
        server.stop
        thread.join
      end
    end
  end
  
  
  context "with worker" do
  
    it "will load a worker and call it" do

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
      
      begin

        meth_name = nil
        ss = TestWorkerServer.new(8001)
        ss.start(Proc.new { |controller|
          #puts controller.params.inspect
          controller.class.send(:include, BackgroundQueue::Worker::Calling)
          # puts "B"
          controller.run_worker({:some=>:context})
          # puts "C"
        })
        
        
        client_config_path = File.expand_path(File.dirname(__FILE__) + '/../../../resources/config-client.yml')
        
        client = BackgroundQueue::Client.new(client_config_path)
        
  
        job_handle = client.add_task(:test_worker, :owner_id, :job_id, :task_id, 2, {:something=>:else}, {:domain=>"www.example.com"} )
  
        ss.wait_to_be_called.should be_true
        
        result = client.get_status(job_handle)
  
        result.code.should eq(:status)
        result.args[:percent].should eq(100)
        result.args[:caption].should eq('Done')

        ss.stop
      ensure
        server.stop
        
        thread.join
      end
    end
    
    
    it "will keep track of summary" do

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
      
      begin

        count = 0
        summary_data = nil 
        meth_name = nil
        ss = TestWorkerServer.new(8001, true)
        ss.start(Proc.new { |controller|
            controller.class.send(:include, BackgroundQueue::Worker::Calling)
            controller.run_worker({:some=>'context'})
        })
        
        
        client_config_path = File.expand_path(File.dirname(__FILE__) + '/../../../resources/config-client.yml')
        
        client = BackgroundQueue::Client.new(client_config_path)
        
  
        job_handle = client.add_tasks(:summary_worker, :owner_id, :job_id, [[:task1_id, {:test_id=>1}], [:task2_id, {:test_id=>2}], [:task3_id, {:mode=>"summary"}, {:send_summary=>true, :weight=>10, :exclude=>true, :synchronous=>true}]], 2, {:something=>:else}, {:domain=>"www.example.com"} )
  
        ss.allow_to_be_called
        ss.wait_to_be_called.should be_true
        
        result = client.get_status(job_handle)
  
        result.code.should eq(:status)
        result.args[:percent].should eq(45)
        result.args[:caption].should eq('Done (2/2)')
        result.args[:meta].should eq({'test_meta'=>"context"})
        
        ss.allow_to_be_called
        ss.wait_to_be_called.should be_true
        
        result = client.get_status(job_handle)
  
        result.code.should eq(:status)
        result.args[:percent].should eq(90)
        result.args[:caption].should eq('Done (2/2)')
        
        ss.allow_to_be_called
        ss.wait_to_be_called.should be_true
        
        result = client.get_status(job_handle)
  
        result.code.should eq(:status)
        result.args[:percent].should eq(100)
        result.args[:caption].should eq('Done')

        ss.stop
      ensure
        server.stop
        
        thread.join
      end
    end
    
  end
end
