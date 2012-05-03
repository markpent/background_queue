require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::BalancedQueue do

  it_behaves_like "a queue registry" do
    let(:new_instance) { BackgroundQueue::ServerLib::BalancedQueue.new(:parent) }
  end
  subject {  BackgroundQueue::ServerLib::BalancedQueue.new(:parent) }
  
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
        ConditionVariable.any_instance.should_receive(:signal)
        subject.should_receive(:add_item).with(anything) { :does_not_matter }
      end
      
      it "adds a new task" do
        BackgroundQueue::ServerLib::TaskRegistry.any_instance.should_receive(:register).with(anything).and_return([:new, nil])
        subject.add_task(SimpleTask.new(:owner_id, :job_id, :task_id, 3))
      end
      
      it "adds a task with existing id thats not running" do
        BackgroundQueue::ServerLib::TaskRegistry.any_instance.should_receive(:register).with(anything).and_return([:existing, :existing_task])
        subject.should_receive(:remove_task).with(:existing_task)
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
      ConditionVariable.any_instance.should_receive(:wait)
      bg = BackgroundQueue::ServerLib::BalancedQueue.new(:parent)
      bg.next_task.should eq(nil)
    end
    
  end
  

end
