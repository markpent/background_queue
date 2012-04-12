require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'

  
class SimpleTask
  attr_accessor :id
  attr_accessor :priority
  
  attr_accessor :owner_id
  attr_accessor :job_id
  
  def initialize(owner_id, job_id, id, priority)
    @owner_id = owner_id
    @job_id = job_id
    @id = id
    @priority = priority
  end
end

describe "BalancedQueue" do

  context "owner registry management" do
    
    subject { BackgroundQueue::ServerLib::BalancedQueue.new }
    
    it "will create an owner queue for a task" do
      BackgroundQueue::ServerLib::Owner.should_receive(:new).with(:owner_id) { :owner_queue}
      subject.__prv__get_owner_queue(:owner_id).should eq([false, :owner_queue])
    end
    
    it "will find existing owner queue" do
      BackgroundQueue::ServerLib::Owner.should_receive(:new).with(:owner_id) { :owner_queue}
      subject.__prv__get_owner_queue(:owner_id)
      BackgroundQueue::ServerLib::Owner.stub(:new).with(:owner_id) { :this_should_not_be_used }
      subject.__prv__get_owner_queue(:owner_id).should eq([true, :owner_queue])
    end
    
  end
  
  before do
    BackgroundQueue::ServerLib::Owner.any_instance.stub(:add_task) do |task|
      @priority = task.priority if @priority.nil? || @priority > task.priority
    end
    
    BackgroundQueue::ServerLib::Owner.any_instance.stub(:priority) do 
      @priority
    end
    
    BackgroundQueue::ServerLib::Owner.any_instance.stub(:set_priority) do |priority|
      @priority = priority
    end
    
    BackgroundQueue::ServerLib::Owner.any_instance.stub(:next_task) do |task|
      @priority += 1 #just assume we lower priority...
    end
  end
    
  context "adding tasks" do

    context "new owner" do
      
      subject { BackgroundQueue::ServerLib::BalancedQueue.new }
      
      it "tracks if the owner priority changed" do
        in_queue, owner = subject.__prv__get_owner_queue(:owner_id)
        subject.__prv__add_task_to_owner(owner, SimpleTask.new(:owner_id, :job_id, :task_id, 3)).should eq([true, nil])
      end
      
      it "will add with correct priority" do
        ConditionVariable.any_instance.should_receive(:signal)
        
        subject.add_task(SimpleTask.new(:owner_id, :job_id, :task_id, 3))
        subject.__prv__get_queues.should have(1).items
        subject.__prv__get_queues.first.priority.should eq(3)
      end
    end
    
    context "existing owner" do
    
      subject { 
        bg = BackgroundQueue::ServerLib::BalancedQueue.new 
        bg.add_task(SimpleTask.new(:owner_id, :job_id, :task_id, 3))
        bg
      }
      
      it "will re-prioritise existing owner to higher priority" do
        subject.__prv__get_queues.should have(1).items
        subject.__prv__get_queues.first.priority.should eq(3)
        subject.add_task(SimpleTask.new(:owner_id, :job_id, :task_id2, 2))
        subject.__prv__get_queues.should have(1).items
        subject.__prv__get_queues.first.priority.should eq(2)
      end
      
      it "will not re-prioritise existing owner to lower priority" do
        subject.__prv__get_queues.should have(1).items
        subject.__prv__get_queues.first.priority.should eq(3)
        subject.add_task(SimpleTask.new(:owner_id, :job_id, :task_id2, 4))
        subject.__prv__get_queues.should have(1).items
        subject.__prv__get_queues.first.priority.should eq(3)
      end
    end
  end
  
  context "getting tasks" do

    subject { 
      bg = BackgroundQueue::ServerLib::BalancedQueue.new 
      bg.add_task(SimpleTask.new(:owner_id, :job_id, :task_id, 3))
      bg.add_task(SimpleTask.new(:owner_id2, :job_id2, :task_id2, 2))
      bg
    }
      
    it "will remove the owner if no tasks left for owner" do
      subject.should_receive(:get_task_from_owner).with(anything) { [true, 2, :task]}
      BackgroundQueue::ServerLib::Owner.any_instance.stub(:empty?) { true }
         
      subject.next_task
      subject.__prv__get_queues.should have(1).items
      subject.__prv__get_queues.first.priority.should eq(3)
      #make sure the owner was removed
      subject.__prv__get_owner_queue(:owner_id2).first.should eq(false)
    end
    
    it "tracks if priority changed when removing task" do
      owner = double("owner")
      owner.stub(:priority) { @priority ||= 2 }
      owner.stub(:next_task) { @priority += 1; :task }
      
      subject.__prv__get_task_from_owner(owner).should eq([true, 2, :task])
    end
    
    it "tracks if priority unchanged when removing task" do
      owner = double("owner")
      owner.stub(:priority) { @priority ||= 2 }
      owner.stub(:next_task) {:task }
      
      subject.__prv__get_task_from_owner(owner).should eq([false, 2, :task])
    end
    
    it "will lower priority when tasks left are lower piority" do
      subject.should_receive(:get_task_from_owner).with(anything) { [true, 2, :task]}
      BackgroundQueue::ServerLib::Owner.any_instance.stub(:empty?) { false }
      
      subject.__prv__get_owner_queue(:owner_id2).last.set_priority(3)
      
      #BackgroundQueue::ServerLib::Owner.any_instance.should_receive(:priority) { 3 }
      
      subject.next_task
      subject.__prv__get_queues.should have(1).items
      subject.__prv__get_queues.first.priority.should eq(3)
      subject.__prv__get_queues.first.should have(2).items
    end
    
    it "will wait on condition if queue is empty" do
      ConditionVariable.any_instance.should_receive(:wait)
      bg = BackgroundQueue::ServerLib::BalancedQueue.new 
      bg.next_task.should eq(nil)
    end
    
  end
  

end
