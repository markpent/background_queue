require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::WorkerThread do
  
  let(:balanced_queue) {
    double("balanced_queue")
  }
  
  let(:workers) {
    double("workers")
  }
  
  let(:server) {
    SimpleServer.new(:task_queue=>balanced_queue, :workers=>workers, :config=>double("conf", :secret=>:secret))
  }
  
  subject { BackgroundQueue::ServerLib::WorkerThread.new(server) }
  
  context "#get_next_task" do
    it "will get the next task from the servers balanced queue" do
      server.task_queue.should_receive(:next_task).and_return(:task)
      server.stub('running?'=>true)
      subject.get_next_task.should eq(:task)
    end
    
    it "will try again if the balanced queue returns nil" do
      count = 0
      server.task_queue.should_receive(:next_task).twice { 
        count += 1
        count == 2 ? :task : nil
      }
      server.stub('running?'=>true)
      subject.get_next_task.should eq(:task)
    end
    
    it "will stop if the server has stopped" do
      server.should_receive(:running?).and_return(false)
      subject.get_next_task.should be_nil
    end
    
  end
  
  
  context "#call_worker" do
    it "will get a worker and call it" do
      server.stub('running?'=>true)
      worker = double("worker")
      task = DefaultTask.new
      BackgroundQueue::ServerLib::WorkerClient.any_instance.should_receive(:send_request).with(worker, task, :secret).and_return(true)
      server.workers.should_receive(:get_next_worker).and_return(worker)
      server.workers.should_receive(:finish_using_worker).with(worker, true)
      subject.call_worker(task).should be_true
    end
    
    it "will keep trying if the worker fails" do
      server.stub('running?'=>true)
      worker = double("worker")
      task = DefaultTask.new
      count = 0
      worker_client1 = double("w1")
      worker_client1.should_receive(:send_request).with(worker, task, :secret).and_return(false)
      worker_client2 = double("w2")
      worker_client2.should_receive(:send_request).with(worker, task, :secret).and_return(true)
      
      subject.should_receive(:build_client).twice {
        count += 1
        count == 1 ? worker_client1 : worker_client2
      }
      server.workers.should_receive(:get_next_worker).twice.and_return(worker)
      server.workers.should_receive(:finish_using_worker).with(worker, false)
      server.workers.should_receive(:finish_using_worker).with(worker, true)
      subject.call_worker(task).should be_true
    end
    
    it "will sleep and try again if there are no workers" do
      server.stub('running?'=>true)
      count = 0
      task = DefaultTask.new
      worker = double("worker")
      server.workers.should_receive(:get_next_worker).twice {
        count += 1
        count == 1 ? nil : worker
      }
      Kernel.should_receive(:sleep).with(1)
      BackgroundQueue::ServerLib::WorkerClient.any_instance.should_receive(:send_request).with(worker, task, :secret).and_return(true)
      server.workers.should_receive(:finish_using_worker).with(worker, true)
      subject.call_worker(task).should be_true
    end
    
    it "will stop trying if the server is not running" do
      server.stub('running?'=>false)
      subject.call_worker(DefaultTask.new).should be_false
    end
  end
  
  context "#run" do
    before do
      count = 0
      server.should_receive('running?').twice {
        count += 1
        count < 2
      }  
    end
    
    it "will keep running while the server is running" do
      subject.should_receive(:get_next_task).and_return(:task)
      subject.should_receive(:call_worker).with(:task)
      subject.run
    end
    
    it "will not call_worker if no task" do
      subject.should_receive(:get_next_task).and_return(nil)
      subject.run
    end
  end
  
end
