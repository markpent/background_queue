require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::BalancedQueue do

  it_behaves_like "a queue registry" do
    let(:server) {
     SimpleServer.new( :thread_manager=>:thread_manager)
    }
    let(:new_instance) { BackgroundQueue::ServerLib::BalancedQueue.new(server) }
  end
  
  let(:thread_manager) {
    tm = double("thread_manager")
    tm.stub(:protect_access).and_yield
    tm.stub(:control_access).and_yield
    tm
  }
  let(:server) {
   SimpleServer.new( :thread_manager=>thread_manager)
  }
  subject {  BackgroundQueue::ServerLib::BalancedQueue.new(server) }
  
  context "callbacks" do
    it "gets the owner_id from tasks" do
      subject.__prv__get_queue_id_from_item(SimpleTask.new(:owner_id, :job_id, :task_id, 3)).should eq(:owner_id)
    end
    
    it "calls add_item to add items to owner" do
      BackgroundQueue::ServerLib::Owner.any_instance.should_receive(:add_item).with(:item)
      subject.__prv__add_item_to_queue(BackgroundQueue::ServerLib::Owner.new(1, :parent), :item)
    end
    
    it "specifies the owner class as its queue class" do
      subject.class.queue_class.should eq(BackgroundQueue::ServerLib::Owner)
    end
  end
  
  context "adding tasks" do
    context "with no existing task running" do
      before do
        thread_manager.should_receive(:signal_access)
        subject.should_receive(:add_item).with(anything) { :does_not_matter }
      end
      
      it "adds a new task" do
        BackgroundQueue::ServerLib::TaskRegistry.any_instance.should_receive(:register).with(anything).and_return([:new, nil])
        subject.add_task(SimpleTask.new(:owner_id, :job_id, :task_id, 3))
      end
      
      it "adds a task with existing id thats not running" do
        BackgroundQueue::ServerLib::TaskRegistry.any_instance.should_receive(:register).with(anything).and_return([:existing, :existing_task])
        subject.should_receive(:remove_item).with(:existing_task)
        subject.add_task(SimpleTask.new(:owner_id, :job_id, :task_id, 3))
      end
    end
    
    it "adds a task with existing id thats running" do
      BackgroundQueue::ServerLib::TaskRegistry.any_instance.should_receive(:register).with(anything).and_return([:waiting, nil])
      subject.should_not_receive(:add_item).with(anything)
      subject.add_task(SimpleTask.new(:owner_id, :job_id, :task_id, 3))
    end
   
  end
  
  context "removing tasks" do
    it "delegates call to queue_registry" do
      subject.should_receive(:remove_item).with(anything) { :does_not_matter }
      subject.remove_task(:task_id)
    end
  end
  
  context "getting tasks" do
    
    it "will wait on condition if queue is empty" do
      thread_manager.should_receive(:wait_on_access)
      bg = BackgroundQueue::ServerLib::BalancedQueue.new(server)
      bg.next_task.should eq(nil)
    end
    
  end
  
  context "#save_to_file" do
    it "will write the tasks as json to file" do
      subject.stub(:register_job)
      thread_manager.stub(:signal_access)

      t1 = BackgroundQueue::ServerLib::Task.new(:owner_id, :job_id, :task_id, 1, :worker, {:a=>'b'}, {:c=>'d'})
      t2 = BackgroundQueue::ServerLib::Task.new(:owner2_id, :job2_id, :task2_id, 2, :worker, {}, {})
      t3 = BackgroundQueue::ServerLib::Task.new(:owner3_id, :job3_id, :task3_id, 3, :worker, {}, {})
      subject.add_task(t1)
      subject.add_task(t2)
      subject.add_task(t3)
      sio = StringIO.new
      subject.save_to_file(sio)

      sio.string.should eq([t1.to_json_object(true),t2.to_json_object(true),t3.to_json_object(true)].to_json)
    end
  end
  
  context "#load_from_file" do
    it "will load the tasks as json from file" do
      subject.stub(:register_job)
      thread_manager.stub(:signal_access)

      t1 = BackgroundQueue::ServerLib::Task.new(:owner_id, :job_id, :task_id, 1, :worker, {:a=>'b'}, {:c=>'d'})
      t2 = BackgroundQueue::ServerLib::Task.new(:owner2_id, :job2_id, :task2_id, 2, :worker, {}, {})
      t3 = BackgroundQueue::ServerLib::Task.new(:owner3_id, :job3_id, :task3_id, 3, :worker, {}, {})
      
      sio = StringIO.new([t1.to_json_object(true),t2.to_json_object(true),t3.to_json_object(true)].to_json)
      subject.load_from_file(sio)

      sio = StringIO.new
      subject.save_to_file(sio)

      sio.string.should eq([t1.to_json_object(true),t2.to_json_object(true),t3.to_json_object(true)].to_json)
    end
  end
  

end
