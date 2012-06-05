require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::ThreadManager do
  

  let(:server) {
    double("server")
  }
  
  subject { BackgroundQueue::ServerLib::ThreadManager.new(server, 5) }
  
  context "#protect_access" do
    it "will grab a mutex and serialize access" do
      Mutex.any_instance.should_receive(:synchronize).and_yield
      subject.protect_access {
        5
      }.should eq(5)
    end
  end
  
  
  context "#control_access" do
    it "will serialize access then execute block if concurrent number of threads is below threshold" do
      subject.control_access {
        5
      }.should eq(5)
    end
    
    it "will wait on condition if number of threads is above threshold" do
      subject.max_threads = 0
      ConditionVariable.any_instance.should_receive(:wait).and_return(nil)
      subject.control_access {
        5
      }.should eq(5)
    end
    
  end
  
  context "#signal_access" do
    it "will signal a waiting thread if concurrent number of threads is below threshold" do
      ConditionVariable.any_instance.should_receive(:signal).and_return(nil)
      subject.signal_access
    end
    
    it "will do nothing is number of threads is above threshold" do
      subject.max_threads = 0
      ConditionVariable.any_instance.should_not_receive(:signal)
      subject.signal_access
    end
  end
  
  context "#wait_on_access" do
    it "will wait on the condition" do
      ConditionVariable.any_instance.should_receive(:wait).and_return(nil)
      subject.wait_on_access
    end
  end
  
  context "#change_concurrency" do
    it "will do nothing if the concurrency is reduced" do
      ConditionVariable.any_instance.should_not_receive(:signal)
      subject.change_concurrency(0)
      subject.max_threads.should eq(0)
    end
    
    it "will wake threads when concurrency is increased" do
      ConditionVariable.any_instance.should_receive(:signal).twice
      subject.change_concurrency(7)
      subject.max_threads.should eq(7)
    end
  end
  
  context "#start" do
    it "will start a number of threads and call run on a worker thread object" do
      Thread.should_receive(:new).twice.and_yield
      subject.max_threads = 2
      runner = double("runner")
      runner.should_receive(:run).twice
      
      BackgroundQueue::ServerLib::WorkerThread.should_receive(:new).twice.and_return(runner)
      
      subject.start(BackgroundQueue::ServerLib::WorkerThread)
      subject.running_threads.should eq(2)
    end
  end
  
  context "#wait" do
    it "will wait for each thread to finish" do
      thread = double("thread")
      thread.should_receive(:join).twice
      Thread.should_receive(:new).twice.and_return(thread)
      subject.max_threads = 2
      subject.start(BackgroundQueue::ServerLib::WorkerThread)
      subject.running_threads.should eq(2)
      subject.wait
      subject.running_threads.should eq(0)
    end
  end
  
end
