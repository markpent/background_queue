require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::WorkerThread do
  
  let(:balanced_queue) {
    double("balanced_queue")
  }
  
  let(:workers) {
    double("workers")
  }
  let(:error_tasks) {
    double("error_tasks")
  }
  
  let(:server) {
    SimpleServer.new(:task_queue=>balanced_queue, :workers=>workers, :config=>double("conf", :secret=>:secret), :error_tasks=>error_tasks)
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
      worker_client = double("worker_client")
      subject.should_receive(:build_client).and_return(worker_client)
      worker_client.should_receive(:send_request).with(worker, task, :secret).and_return(:ok)
      server.workers.should_receive(:get_next_worker).and_return(worker)
      server.workers.should_receive(:finish_using_worker).with(worker, true)
      server.task_queue.should_receive(:finish_task).with(task)
      subject.call_worker(task).should be_true
    end
    
    it "will regegister as a failed worker if send_request returns :fatal_error" do
      server.stub('running?'=>true)
      worker = double("worker")
      task = DefaultTask.new
      server.task_queue.should_receive(:add_task_to_error_list).with(task)
      worker_client = double("worker_client")
      subject.should_receive(:build_client).and_return(worker_client)
      worker_client.should_receive(:send_request).with(worker, task, :secret).and_return(:fatal_error)
      server.workers.should_receive(:get_next_worker).and_return(worker)
      server.workers.should_receive(:finish_using_worker).with(worker, false)
      subject.call_worker(task).should be_true
    end
    
    it "will reregister as an ok worker if send_request returns :worker_error" do
      server.stub('running?'=>true)
      worker = double("worker")
      task = DefaultTask.new
      task.should_receive(:increment_worker_error_count)
      task.should_receive(:get_worker_error_count).and_return(0)
      worker_client = double("worker_client")
      subject.should_receive(:build_client).and_return(worker_client)
      worker_client.should_receive(:send_request).with(worker, task, :secret).and_return(:worker_error)
      server.workers.should_receive(:get_next_worker).and_return(worker)
      server.workers.should_receive(:finish_using_worker).with(worker, true)
      server.task_queue.should_receive(:finish_task).with(task)
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
      BackgroundQueue::ServerLib::WorkerClient.any_instance.should_receive(:send_request).with(worker, task, :secret).and_return(:ok)
      server.workers.should_receive(:finish_using_worker).with(worker, true)
      server.task_queue.should_receive(:finish_task).with(task)
      subject.call_worker(task).should be_true
    end
    
    it "will stop trying if the server is not running" do
      server.stub('running?'=>false)
      task = DefaultTask.new
      server.task_queue.should_receive(:finish_task).with(task)
      server.task_queue.should_receive(:add_task).with(task)
      subject.call_worker(task).should be_false
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
