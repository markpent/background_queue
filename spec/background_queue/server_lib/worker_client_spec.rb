require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::WorkerClient do

  subject { BackgroundQueue::ServerLib::WorkerClient.new(SimpleServer.new({:config=>double("cfg", {:address=>double("addr", {:port=>123})} )})) }
  
  
  context "#build_request" do
    it "builds a request payload from a task" do
      task = SimpleTask.new(:owner_id, :job_id, :task_id, 3, { :domain=>"www.example.com" })
      task.should_receive(:to_json).and_return(:the_json)
      Net::HTTP::Post.any_instance.should_receive(:set_form_data).with({:task=>:the_json, :auth=>"auth", :server_port=>123})
      Net::HTTP::Post.any_instance.should_receive("[]=".intern).with("host", "www.example.com")
      Net::HTTP::Post.any_instance.should_receive("[]=".intern).with(any_args).at_least(:once)
      request = subject.__prv__build_request(URI("http://127.0.0.1:3000/worker/run"), task, "auth")
    end
  end
  
  context "#send_request" do
    it "uses http client to call the worker" do
      uri = URI("http://127.0.0.1:3000/worker/run")
      worker_config = BackgroundQueue::ServerLib::Worker.new(uri)
      task = SimpleTask.new(:owner_id, :job_id, :task_id, 3, { :domain=>"www.example.com" })
      subject.should_receive(:build_request).with(uri, task, "auth").and_return(:post_request)
      
      http_client = double("http_client")
      http_client.should_receive("read_timeout=").with(86400)

      subject.should_receive(:build_http_client).with(worker_config).and_return(http_client)
      
      http_instance = double("http")
      http_instance.should_receive(:request).with(:post_request).and_yield(:http_response)
      subject.should_receive(:read_response).with(worker_config, :http_response, task).and_return(true)
      subject.should_receive('has_received_finish?').and_return(true)
      
      http_client.should_receive(:start).and_yield(http_instance)
      
      subject.send_request(worker_config, task, "auth").should be_true
      
    end
    
    it "will fail if the connection fails" do
      uri = URI("http://127.0.0.1:3000/worker/run")
      worker_config = BackgroundQueue::ServerLib::Worker.new(uri)
      task = SimpleTask.new(:owner_id, :job_id, :task_id, 3, { :domain=>"www.example.com" })
      subject.should_receive(:build_request).with(uri, task, "auth").and_return(:post_request)
      Net::HTTP.any_instance.should_receive(:start).and_raise("connection error")
      subject.send_request(worker_config, task, "auth").should eq(:fatal_error)
    end
    
    it "will fail if the finish status is not sent" do
      uri = URI("http://127.0.0.1:3000/worker/run")
      worker_config = BackgroundQueue::ServerLib::Worker.new(uri)
      task = SimpleTask.new(:owner_id, :job_id, :task_id, 3, { :domain=>"www.example.com" })
      subject.should_receive(:build_request).with(uri, task, "auth").and_return(:post_request)
      
      http_client = double("http_client")
      http_client.should_receive("read_timeout=").with(86400)

      subject.should_receive(:build_http_client).with(worker_config).and_return(http_client)
      
      http_instance = double("http")
      http_instance.should_receive(:request).with(:post_request).and_yield(:http_response)
      subject.should_receive(:read_response).with(worker_config, :http_response, task).and_return(true)
      subject.should_receive('has_received_finish?').and_return(false)
      
      http_client.should_receive(:start).and_yield(http_instance)
      
      subject.send_request(worker_config, task, "auth").should be_true
    end
  end
  
  context "#read_response" do
    it "will read the streamed response" do
      http_response = double("response", :code=>"200")
      http_response.should_receive(:read_body).and_yield("data")
      subject.should_receive(:process_chunk).with("data", :task)
      subject.__prv__read_response(:worker_config, http_response, :task)
    end
    
    it "will raise an error if response is not 200" do
      http_response = double("response", :code=>"400")
      worker_config = double("wc", :url=>"uri")
      expect { subject.__prv__read_response(worker_config, http_response, :task) }.to raise_exception
    end
  end
  
  context "#process_response_chunk" do
    it "will handle a reponse in 1 chunk" do
      subject.should_receive(:process_line).with("data", :task)
      subject.__prv__process_chunk("data\n", :task)
    end
    
    it "will handle a partial response" do
      subject.should_not_receive(:process_line)
      subject.__prv__process_chunk("data", :task)
    end
    
    it "will handle multiple responses in 1 chunk" do
      subject.should_receive(:process_line).with("data", :task).once
      subject.should_receive(:process_line).with("data2", :task).once
      subject.__prv__process_chunk("data\ndata2\n", :task)
    end
    
    it "will handle multiple partial responses" do
      subject.should_receive(:process_line).with("data", :task).once
      subject.should_receive(:process_line).with("data2", :task).once
      subject.should_receive(:process_line).with("data3", :task).once
      subject.should_receive(:process_line).with("data4", :task).once
      subject.__prv__process_chunk("da", :task)
      subject.__prv__process_chunk("ta\ndata2\nda", :task)
      subject.__prv__process_chunk("ta3\nda", :task)
      subject.__prv__process_chunk("ta4\n", :task)
    end
  end
  
  context "#process_line" do
    it "loads from json" do
      subject.should_receive(:set_worker_status).with({'a'=>'b'}, :task)
      subject.__prv__process_line('{ "a":"b"}', :task).should be_true
    end
    
    it "fails gracefully on invalid json" do
      subject.__prv__process_line('{ "a":"b"', DefaultTask.new).should be_false
    end
  end
  
  context "#set_worker_status" do
    let(:status) {
      {"a"=>"b"}
    }
    let(:kstatus) {
      {:a=>"b"}
    }
    let(:task) {DefaultTask.new}
    
    it "calls set_worker_status on the task" do
      BackgroundQueue::Utils::AnyKeyHash.should_receive(:new).with(status).and_return(kstatus)
      task.should_receive(:set_worker_status).with(kstatus)
      subject.__prv__set_worker_status(status, task)
    end
    
    it "will call set_has_received_finish if status[:finished]" do
      finish_status = {
        :finished=>true
      }
      BackgroundQueue::Utils::AnyKeyHash.should_receive(:new).with(status).and_return(finish_status)
      subject.should_receive(:set_has_received_finish)
      task.should_not_receive(:set_worker_status).with(kstatus)
      subject.__prv__set_worker_status(status, task)
    end
  end
  
  
  context "can handle thread cancelling" do
    #this can cause issues with other tests....
    it "will return false if server stopped", :can_be_flakey=>true do
      
      mutex = Mutex.new
      resource = ConditionVariable.new
      
      mutex2 = Mutex.new
      resource2 = ConditionVariable.new

      run_request = false
      ss = TestWorkerServer.new(8001)
      begin
        ss.start(Proc.new { |controller|
          #puts "in proc"
            
          mutex2.synchronize {
            resource2.signal
          }
          #puts "in proc: waiting" 
          mutex.synchronize {
            resource.wait(mutex)
          }
          #puts "waited"
          run_request = true
          controller.render :text =>{:percent=>100, :caption=>"Done"}.to_json, :type=>"text/text"
        })
        
        
        uri = URI("http://127.0.0.1:8001/background_queue")
        worker_config = BackgroundQueue::ServerLib::Worker.new(uri)
        task = SimpleTask.new(:owner_id, :job_id, :task_id, 3, { :domain=>"www.example.com" })
        
        call_result = nil
        t1 = Thread.new {
          #puts "calling"
          begin
            status = Timeout::timeout(2) {
              call_result = subject.send_request(worker_config, task, "abcd")
             # puts "called"
            }
          rescue Timeout::Error=>te
            #puts "timeout"
            call_result = :timeout
          end
          mutex2.synchronize {
            resource2.signal
          }
        }
  
        #wait until we know the request has been sent and is processing
        mutex2.synchronize {
          resource2.wait(mutex2)
        }
        run_request.should be_false
        #puts "cancelling"
        t1.raise BackgroundQueue::ServerLib::ThreadManager::ForcedStop.new("Timeout when forcing threads to stop")
        
        #puts "canceled"
        #wait until we know the request has been cancelled
        mutex2.synchronize {
          resource2.wait(mutex2)
        }
        call_result.should eq(:stop)
        run_request.should be_false
  
        mutex.synchronize {
          resource.signal
        }
       
        
        t1.join
      ensure
        ss.stop
      end
      
    end
    
    it "will do nothing if not started" do
      
    end
    
  end
  
  
  
end
