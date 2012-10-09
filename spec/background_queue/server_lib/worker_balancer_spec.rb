require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::WorkerBalancer do

 
  
  context "#initialize" do
    it "loads the workers from the config" do
      config = BackgroundQueue::ServerLib::Config.new([double("wc", :uri=>:worker_1), double("wc", :uri=>:worker_2)], :secret, :memcache, :address, :cons, :sopts, :task_file)
      server = SimpleServer.new(:config=>config)
      
      balancer = BackgroundQueue::ServerLib::WorkerBalancer.new(server)
      balancer.available_workers.worker_list[0].uri.should eq(:worker_1)
      balancer.available_workers.worker_list[1].uri.should eq(:worker_2)
    end
  end
  
  context "#initialized" do
  
    let(:config) {
      BackgroundQueue::ServerLib::Config.new([double("wc", :uri=>:worker_1), double("wc", :uri=>:worker_2), double("w3", :uri=>:worker_3)], :secret, :memcache, :address, :cons, :sopts, :task_file)
    }
    subject { BackgroundQueue::ServerLib::WorkerBalancer.new(SimpleServer.new(:config=>config)) }
     
     
    context "#register_start" do
      it "will increment the running count for the worker and reposition it" do
        w1 = subject.available_workers.worker_list[0]
        w1.connections.should eq(0)
        subject.__prv__register_start(w1)
        w1.connections.should eq(1)
        subject.available_workers.worker_list[0].should_not be(w1)
        subject.available_workers.worker_list.last.should be(w1)
      end
    end
    
    context "#register_finish" do
      it "will decrement the running count for the worker and reposition it" do
        w1 = subject.available_workers.worker_list.last
        w1.connections.should eq(0)
        subject.__prv__register_finish(w1)
        w1.connections.should eq(-1)
        subject.available_workers.worker_list.last.should_not be(w1)
        subject.available_workers.worker_list.first.should be(w1)
      end
    end
    
    context "#register_offline" do
      it "will remove the worker from the available workers and add it to offline workers" do
        w1 = subject.available_workers.worker_list[0]
        subject.__prv__register_offline(w1)
        w1.offline?.should be_true
        subject.available_workers.worker_list[0].should_not be(w1)
        subject.offline_workers.first.should be(w1)
      end
      
      it "will will not double add workers to offline list" do
        w1 = subject.available_workers.worker_list[0]
        subject.__prv__register_offline(w1)
        subject.__prv__register_offline(w1)
        subject.offline_workers.should have(1).item
      end
    end
    
    context "#register_online" do
      it "will add the worker back into the available workers list" do
        w1 = subject.available_workers.worker_list[0]
        subject.__prv__register_offline(w1)
        w1.offline?.should be_true
        subject.available_workers.worker_list[0].should_not be(w1)
        subject.offline_workers.first.should be(w1)
        
        subject.__prv__register_online(w1)
        w1.offline?.should be_false
        subject.available_workers.worker_list[0].should be(w1)
        subject.offline_workers.should have(0).items
      end
    end
    
    context "#build_poll_task" do
      it "creates a fake task using itself as the job" do
        task = subject.__prv__build_poll_task
        task.worker.should eq(:poll_worker)
        subject.__prv__build_poll_task.should be(task)
      end
    end
    
    context "#check_offline" do
      it "will poll the workers" do
        w1 = subject.available_workers.worker_list[0]
        subject.__prv__register_offline(w1)
        BackgroundQueue::ServerLib::WorkerClient.any_instance.should_receive(:send_request).with(w1, subject.__prv__build_poll_task,  :secret ).and_return(true)
        subject.should_receive(:register_online).with(w1)
        subject.check_offline
        
      end
    end
    
    context "#get_next_worker" do
      it "will get the worker with the least number of active connections" do
        w1 = subject.available_workers.worker_list[0]
        subject.should_receive(:register_start).with(w1)
        subject.get_next_worker.should be(w1)
      end
      
      it "will return nil if no workers available" do
        subject.available_workers.worker_list[0] = nil
        subject.get_next_worker.should be_nil
      end
    end
    
    context "#finish_using_worker" do
      it "will not register offline if online" do
        subject.should_not_receive(:register_offline).with(:worker)
        subject.should_receive(:register_finish).with(:worker)
        subject.finish_using_worker(:worker, true)
      end
      
      it "will register offline if not online" do
        subject.should_receive(:register_offline).with(:worker)
        subject.finish_using_worker(:worker, false)
      end
    end
  end
end
