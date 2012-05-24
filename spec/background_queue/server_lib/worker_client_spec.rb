require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::WorkerClient do

  subject { BackgroundQueue::ServerLib::WorkerClient.new(:server) }
  
  
  context "#build_request" do
    it "builds a request payload from a task" do
      task = SimpleTask.new(:owner_id, :job_id, :task_id, 3, { :domain=>"www.example.com" })
      task.should_receive(:to_json).and_return(:the_json)
      Net::HTTP::Post.any_instance.should_receive(:set_form_data).with({:task=>:the_json, :auth=>"auth"})
      Net::HTTP::Post.any_instance.should_receive("[]=".intern).with("host", "www.example.com")
      Net::HTTP::Post.any_instance.should_receive("[]=".intern).with(any_args).at_least(:once)
      request = subject.build_request("http://127.0.0.1:3000/worker/run", task, "auth")
    end
  end
  
  context "#send_request" do
    it "uses http client to call the worker" do
      worker_config = BackgroundQueue::ServerLib::Config::Worker.new("http://127.0.0.1:3000/worker/run")
      task = SimpleTask.new(:owner_id, :job_id, :task_id, 3, { :domain=>"www.example.com" })
      subject.should_receive(:build_request).with("http://127.0.0.1:3000/worker/run", task, "auth").and_return(:post_request)
      
      http_instance = double("http")
      http_instance.should_receive(:request).with(:post_request).and_yield(:http_response)
      subject.should_receive(:read_response).with(:http_response, task).and_return(true)
      
      Net::HTTP.should_receive(:start).with("127.0.0.1", 3000).and_yield(http_instance)
      subject.send_request(worker_config, task, "auth").should be_true
      
    end
    
    it "will fail if the connection fails" do
      worker_config = BackgroundQueue::ServerLib::Config::Worker.new("http://127.0.0.1:3000/worker/run")
      task = SimpleTask.new(:owner_id, :job_id, :task_id, 3, { :domain=>"www.example.com" })
      subject.should_receive(:build_request).with("http://127.0.0.1:3000/worker/run", task, "auth").and_return(:post_request)
      Net::HTTP.should_receive(:start).with("127.0.0.1", 3000).and_raise("connection error")
      subject.send_request(worker_config, task, "auth").should be_false
    end
  end
  
  context "#read_response" do
    it "will read the streamed response" do
      http_response = double("response", :code=>"200")
      http_response.should_receive(:read_body).and_yield("data")
      subject.should_receive(:process_chunk).with("data", :task)
      subject.read_response(http_response, :task)
    end
    
    it "will raise an error if response is not 200" do
      http_response = double("response", :code=>"400")
      expect { subject.read_response(http_response, :task) }.to raise_exception
    end
  end
  
  context "#process_response_chunk" do
    it "will handle a reponse in 1 chunk" do
      subject.should_receive(:process_line).with("data", :task)
      subject.process_chunk("data\n", :task)
    end
    
    it "will handle a partial response" do
      subject.should_not_receive(:process_line)
      subject.process_chunk("data", :task)
    end
    
    it "will handle multiple responses in 1 chunk" do
      subject.should_receive(:process_line).with("data", :task).once
      subject.should_receive(:process_line).with("data2", :task).once
      subject.process_chunk("data\ndata2\n", :task)
    end
    
    it "will handle multiple partial responses" do
      subject.should_receive(:process_line).with("data", :task).once
      subject.should_receive(:process_line).with("data2", :task).once
      subject.should_receive(:process_line).with("data3", :task).once
      subject.should_receive(:process_line).with("data4", :task).once
      subject.process_chunk("da", :task)
      subject.process_chunk("ta\ndata2\nda", :task)
      subject.process_chunk("ta3\nda", :task)
      subject.process_chunk("ta4\n", :task)
    end
  end
  
  context "#process_line" do
    it "loads from json" do
      subject.should_receive(:set_worker_status).with({'a'=>'b'}, :task)
      subject.process_line('{ "a":"b"}', :task).should be_true
    end
    
    it "fails gracefully on invalid json" do
      subject.process_line('{ "a":"b"', :task).should be_false
    end
  end
  
  context "#set_worker_status" do
    it "calls set_worker_status on the task" do
      task = double("task")
      
      BackgroundQueue::Utils::AnyKeyHash.should_receive(:new).with(:status).and_return(:kstatus)
      task.should_receive(:set_worker_status).with(:kstatus)
      subject.set_worker_status(:status, task)
    end
  end
  
  context "#call_worker" do
    xit "will call the worker and handle the response" do
      
    end
  end
  
end
