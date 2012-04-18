require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::TaskRegistry do

  let(:task) { SimpleTask.new(:owner_id, :job_id, :task_id, 3) }
  let(:task2) { SimpleTask.new(:owner_id, :job_id, :task_id, 3) }
  
  context "#register_waiting_task" do
    it "will add task to waiting list" do
      subject.register_waiting_task(task)
      subject.waiting_tasks[:task_id].should eq(task)
    end
    
    it "will remove and existing waiting task with same id" do
      subject.register_waiting_task(task)
      subject.register_waiting_task(task2)
      subject.waiting_tasks[:task_id].should_not eq(task)
      subject.waiting_tasks[:task_id].should eq(task2)
    end
  end
  
  context "#get_waiting_task" do
    it "will get a matching task and remove it from the list" do
      subject.register_waiting_task(task)
      subject.waiting_tasks.should have(1).item
      subject.get_waiting_task(:task_id).should eq(task)
      subject.waiting_tasks.should have(0).items
    end
    
    it "will return nil if not waiting task" do
      subject.get_waiting_task(:task_id).should eq(nil)
    end
  end

  context "#register" do
    it "will add the task if it does not exist and return :new" do
      subject.register(task).should eq([:new, nil])
      subject.tasks.should have(1).item
    end
    
    it "will add the task to waiting list if running and return :waiting" do
      subject.register(task)
      task.running = true
      subject.register(task2).should eq([:waiting, nil])
    end
    
    it "will replace an existing task and return the existing task" do
      subject.register(task)
      subject.register(task2).should eq([:existing, task])
    end
  end
  
  context "#de_register" do
    it "will remove the task from the list of tasks and return nil if none are waiting" do
      subject.register(task)
      subject.de_register(task.id).should eq(nil)
    end
    
    it "will remove the task from the list of tasks and return waiting task if none are waiting" do
      subject.register(task)
      task.running = true
      subject.register(task2)
      subject.de_register(task.id).should eq(task2)
      subject.tasks[task.id].should eq(task2)
    end
  end
end
