require 'background_queue_server'

shared_examples "a queue registry" do

  context "queue registry management" do
    
    subject { new_instance }
    
    it "will create an queue" do
      subject.should_receive(:create_queue).with(:queue_id) { :the_queue}
      subject.__prv__get_queue(:queue_id, true).should eq([false, :the_queue])
    end
    
    it "will find existing queue" do
      subject.should_receive(:create_queue).with(:queue_id) { :the_queue}
      subject.__prv__get_queue(:queue_id, true)
      subject.stub(:create_queue).with(:queue_id) { :this_should_not_be_used }
      subject.__prv__get_queue(:queue_id, true).should eq([true, :the_queue])
    end
    
  end
  
  
  context "queue items" do
    let(:queue_class) { described_class.queue_class }
    
    let(:task1) { SimpleTask.new(:owner_id, :job_id, :task_id, 3) }
    let(:task2) { SimpleTask.new(:owner_id2, :job_id, :task_id2, 2) }
    
    before do
      queue_class.any_instance.stub(:add_item) do |item|
        @priority = item.priority if @priority.nil? || @priority > item.priority
      end
      
      queue_class.any_instance.stub(:priority) do 
        @priority
      end
      
      queue_class.any_instance.stub(:set_priority) do |priority|
        @priority = priority
      end
      
      queue_class.any_instance.stub(:next_item) do
        @priority += 1 #just assume we lower priority...
      end
    end
      
    context "#add_item" do

      context "new queue" do
        
        subject { new_instance }
        
        it "tracks if the queue priority changed" do
          in_queue, queue = subject.__prv__get_queue(:queue_id, true)
          subject.__prv__track_priority_when_adding_to_queue(queue, task1).should eq([true, nil])
        end
        
        it "will add with correct priority" do

          subject.add_item(task1)
          subject.__prv__get_queues.should have(1).items
          subject.__prv__get_queues.first.priority.should eq(3)
        end
      end
      
      context "existing queue" do
      
        subject { 
          bg = new_instance
          bg.add_item(task1)
          bg
        }
        
        it "will re-prioritise existing queue to higher priority" do
          subject.__prv__get_queues.should have(1).items
          subject.__prv__get_queues.first.priority.should eq(3)
          subject.add_item(SimpleTask.new(:owner_id, :job_id, :task_id2, 2))
          subject.__prv__get_queues.should have(1).items
          subject.__prv__get_queues.first.priority.should eq(2)
        end
        
        it "will not re-prioritise existing owner to lower priority" do
          subject.__prv__get_queues.should have(1).items
          subject.__prv__get_queues.first.priority.should eq(3)
          subject.add_item(SimpleTask.new(:owner_id, :job_id, :task_id2, 4))
          subject.__prv__get_queues.should have(1).items
          subject.__prv__get_queues.first.priority.should eq(3)
        end
      end
    end
    
    context "#next_item" do
  
      subject { 
        bg = new_instance
        bg.stub(:get_queue_id_from_item) { |item| item.owner_id} 
        bg.add_item(task1)
        bg.add_item(task2)
        bg
      }
        
      it "will add to stalled items if no items left for queue" do
        subject.should_receive(:remove_item_from_queue).with(any_args) { [true, 2, :task]}
        queue_class.any_instance.stub(:empty?) { true }
        subject.should_receive(:stall_queue)
        subject.__prv__get_queue_for_priority(2, false)
        subject.next_item.should eq(:task)
        subject.__prv__get_queues.should have(1).items
        subject.__prv__get_queues.first.priority.should eq(3)
        #make sure the owner was removed
        subject.__prv__get_queue(:owner_id2, true).first.should eq(false)
      end
      
      
      
      it "will lower priority when items left are lower priority" do
        subject.should_receive(:remove_item_from_queue).with(any_args) { [true, 2, :task]}
        queue_class.any_instance.stub(:empty?) { false }
        
        subject.__prv__get_queue(:owner_id2, true).last.set_priority(3)
        
        subject.next_item
        subject.__prv__get_queues.should have(1).items
        subject.__prv__get_queues.first.priority.should eq(3)
        subject.__prv__get_queues.first.should have(2).items
      end
      
      
    end
    
    context "#remove_item_from_queue" do
      
      subject { 
        bg = new_instance
        bg.stub(:get_queue_id_from_item) { |item| item.owner_id} 
        bg.add_item(task1)
        bg.add_item(task2)
        bg
      }
      
      it "tracks if priority changed when removing next item" do
        owner = double("owner")
        owner.stub(:priority) { @priority ||= 2 }
        owner.stub(:next_item) { @priority += 1; :task }
        
        subject.__prv__remove_item_from_queue(owner, :next).should eq([true, 2, :task])
      end
      
      it "tracks if priority unchanged when removing next item" do
        owner = double("owner")
        owner.stub(:priority) { @priority ||= 2 }
        owner.stub(:next_item) {:task }
        
        subject.__prv__remove_item_from_queue(owner, :next).should eq([false, 2, :task])
      end
      
      it "tracks if priority changed when removing specific item" do
        owner = double("owner")
        owner.stub(:priority) { @priority ||= 2 }
        owner.stub(:remove_item) { @priority += 1; :task }
        
        subject.__prv__remove_item_from_queue(owner, :task).should eq([true, 2, :task])
      end
      
      it "tracks if priority unchanged when removing specific item" do
        owner = double("owner")
        owner.stub(:priority) { @priority ||= 2 }
        owner.stub(:remove_item) {:task }
        
        subject.__prv__remove_item_from_queue(owner, :task).should eq([false, 2, :task])
      end
      
    end
    
    
    context "#remove_item" do

      subject { 
        bg = new_instance
        bg.stub(:get_queue_id_from_item) { |item| item.owner_id} 
        bg.add_item(task1)
        bg.add_item(task2)
        bg
      }
        
      it "will remove the queue if no items left for queue" do
        subject.should_receive(:remove_item_from_queue).with(any_args) { [true, 3, :task]}
        queue_class.any_instance.stub(:empty?) { true }
           
        subject.remove_item(task1)
        subject.__prv__get_queues.should have(1).items
        subject.__prv__get_queues.first.priority.should eq(2)
        #make sure the owner was removed
        subject.__prv__get_queue(:owner_id, false).first.should be_false
      end

      it "will lower priority when items left are lower priority" do
        
        subject.add_item(SimpleTask.new(:owner_id2, :job_id, :task_id3, 3))
        
        subject.should_receive(:remove_item_from_queue).with(any_args) { [true, 2, :task]}
        queue_class.any_instance.stub(:empty?) { false }
        
        subject.__prv__get_queue(:owner_id2, true).last.set_priority(3) #need to manually set the priority to 3 because we are mocking remove_item_from_queue
        
        subject.remove_item(task2)
        subject.__prv__get_queues.should have(1).items #both owners should be at same priority (3)
        subject.__prv__get_queues.first.priority.should eq(3)
        subject.__prv__get_queues.first.should have(2).items
      end
    end
  end
  
  
end
