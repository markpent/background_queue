require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')
require 'background_queue_server'


describe "Queue Integration" do


  context "Adding And Removing Tasks" do
    
    subject { BackgroundQueue::ServerLib::BalancedQueue.new }
    
    it "single task" do
      task = SimpleTask.new(:owner_id, :job_id, :task_id, 2)
      subject.add_task(task)
      subject.peek.priority.should eq(2)
    end
    
    it "2 tasks against same owner" do
      subject.add_task(SimpleTask.new(:owner_id, :job_id, :task_id, 2))
      subject.add_task(SimpleTask.new(:owner_id, :job2_id, :task2_id, 2))
      subject.peek.priority.should eq(2)
      subject.number_of_priorities.should eq(1)
      subject.number_if_items_at_priority(2).should eq(1)
      
      subject.peek.number_of_priorities.should eq(1)
      subject.peek.number_if_items_at_priority(2).should eq(2)

      subject.next_task.id.should eq(:task_id)
      subject.peek.number_if_items_at_priority(2).should eq(1)
      subject.next_task.id.should eq(:task2_id)
    end
    
    it "Adds 3 task against same owner with different priority" do
      subject.add_task(SimpleTask.new(:owner_id, :job_id, :task_id, 3))
      subject.add_task(SimpleTask.new(:owner_id, :job2_id, :task2_id, 2))
      subject.add_task(SimpleTask.new(:owner_id, :job2_id, :task3_id, 4))

      subject.next_task.id.should eq(:task2_id)    
      subject.next_task.id.should eq(:task_id) 
      subject.next_task.id.should eq(:task3_id) 
    end
    
    it "Adds multiple tasks" do
      subject.add_task(SimpleTask.new(:owner_id, :job_id, :task_id, 3))
      subject.add_task(SimpleTask.new(:owner_id, :job2_id, :task2_id, 2))
      subject.add_task(SimpleTask.new(:owner_id, :job2_id, :task3_id, 4))
      subject.add_task(SimpleTask.new(:owner2_id, :job2_id, :task4_id, 1))
      subject.add_task(SimpleTask.new(:owner2_id, :job2_id, :task5_id, 1))
      subject.add_task(SimpleTask.new(:owner3_id, :job3_id, :task6_id, 1))
      subject.add_task(SimpleTask.new(:owner_id, :job4_id, :task7_id, 1))

      subject.next_task.id.should eq(:task4_id)    
      subject.next_task.id.should eq(:task6_id) 
      subject.next_task.id.should eq(:task7_id) 
      subject.next_task.id.should eq(:task5_id) 
      subject.next_task.id.should eq(:task2_id) 
      subject.next_task.id.should eq(:task_id) 
      subject.next_task.id.should eq(:task3_id) 
    end
  
  end

end
