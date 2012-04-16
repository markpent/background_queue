require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::BalancedQueue do

  it_behaves_like "a queue registry" do
    let(:new_instance) { BackgroundQueue::ServerLib::BalancedQueue.new }
  end
  
  context "callbacks" do
    it "gets the owner_id from tasks" do
      subject.__prv__get_queue_id_from_item(SimpleTask.new(:owner_id, :job_id, :task_id, 3)).should eq(:owner_id)
    end
    
    it "calls add_item to add items to owner" do
      BackgroundQueue::ServerLib::Owner.any_instance.should_receive(:add_item).with(:item)
      subject.__prv__add_item_to_queue(BackgroundQueue::ServerLib::Owner.new(1), :item)
    end
    
    it "specifies the owner class as its queue class" do
      subject.class.queue_class.should eq(BackgroundQueue::ServerLib::Owner)
    end
  end
  
  context "adding tasks" do
    it "will signal condition" do
      ConditionVariable.any_instance.should_receive(:signal)
      subject.should_receive(:add_item).with(anything) { :does_not_matter }
      subject.add_task(SimpleTask.new(:owner_id, :job_id, :task_id, 3))
    end
  end
  
  context "getting tasks" do
    
    it "will wait on condition if queue is empty" do
      ConditionVariable.any_instance.should_receive(:wait)
      bg = BackgroundQueue::ServerLib::BalancedQueue.new 
      bg.next_task.should eq(nil)
    end
    
  end
  

end
