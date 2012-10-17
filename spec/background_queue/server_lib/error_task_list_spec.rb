require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::ErrorTaskList do

  let(:server) {
    SimpleServer.new
  }
  
  subject { 
    BackgroundQueue::ServerLib::ErrorTaskList.new(server)
  }
  
  let(:task) {
    double("task", :get_error_count=>1, :id=>:task1)
  }
  let(:task2) {
    double("task2", :get_error_count=>1, :id=>:task2)
  }
  let(:task3) {
    double("task3", :get_error_count=>1, :id=>:task3)
  }
  let(:task4) {
    double("task4", :get_error_count=>1, :id=>:task4)
  }
  
  
  context "#add_task" do
    it "will calculate the delay then add it to the list using it" do
      subject.should_receive(:calculate_delay).with(1).and_return(1)
      subject.should_receive(:add_item).with(task, 101)
      Time.any_instance.should_receive(:to_i).and_return(100)
      task.should_receive(:increment_error_count)
      subject.add_task(task)
    end
  end
  
  context "#calculate_delay" do
    it "will square the error count" do
      subject.calculate_delay(1).should eq(1)
      subject.calculate_delay(2).should eq(4)
      subject.calculate_delay(3).should eq(9)
      subject.calculate_delay(10).should eq(100)
    end
    
    it "will use a threshold (120)" do
      subject.calculate_delay(50).should eq(120)
    end
  end
  
  context "#add_item" do
    it "will add an item using the scheduled time as key" do
      subject.should_receive(:queue_next_event).with(10)
      subject.add_item(task, 10)
      subject.tasks.size.should eq(1)
      subject.tasks.min_key.should be(10)
      subject.tasks.delete_min.should eq([task])
    end
    
    it "will add the task to an event at the same time" do
      subject.should_receive(:queue_next_event).twice.with(10)
      subject.should_receive(:queue_next_event).with(20)
      subject.add_item(task, 10)
      subject.add_item(task2, 10)
      subject.add_item(task3, 20)
      subject.tasks.size.should eq(2)
      subject.tasks.min_key.should be(10)
      subject.tasks.delete_min.should eq([task, task2])
      subject.tasks.min_key.should be(20)
      subject.tasks.delete_min.should eq([task3])
    end
  end
  
  context "#queue_next_event" do
    it "will queue a new time if its closer then the last" do
      timer = double("timer")
      timer.should_receive(:cancel)
      BackgroundQueue::ServerLib::ErrorTaskList::RunAt.should_receive(:new).with(10).and_return(timer)
      BackgroundQueue::ServerLib::ErrorTaskList::RunAt.should_receive(:new).with(5).and_return(timer)
      subject.queue_next_event(10)
      subject.queue_next_event(5)
    end
    
    it "will not queue a new event if its furhter away" do
      timer = double("timer")
      BackgroundQueue::ServerLib::ErrorTaskList::RunAt.should_receive(:new).with(10).and_return(timer)
      subject.queue_next_event(10)
      subject.queue_next_event(20)
    end
    
    it "will fire an event" do
      subject.should_receive(:next_event)
      subject.queue_next_event(Time.now.to_f + 0.1)
      subject.wait_for_event
    end
  end
  
  context "#next_event" do
    it "will get all the tasks before the current time and re-add them" do
      subject.tasks[Time.now.to_f] = [task, task2]
      subject.tasks[Time.now.to_f + 0.01] = [task3]
      task_at = Time.now.to_f + 1.0
      subject.tasks[task_at] = [task4]
      server.task_queue = double("tq")
      server.task_queue.should_receive(:finish_task).with(task)
      server.task_queue.should_receive(:add_task).with(task)
      server.task_queue.should_receive(:finish_task).with(task2)
      server.task_queue.should_receive(:add_task).with(task2)
      server.task_queue.should_receive(:finish_task).with(task3)
      server.task_queue.should_receive(:add_task).with(task3)
      subject.should_receive(:queue_next_event).with(task_at)
      subject.next_event
      subject.tasks.size.should eq(1)
    end
  end
  
  context "RunAt" do
    it "will run a task at the specificied time" do
      run_at = Time.now.to_f + 0.1
      when_run = 0
      runner = BackgroundQueue::ServerLib::ErrorTaskList::RunAt.new(run_at) {
        when_run = Time.now.to_f
      }
      runner.wait_for_run
      when_run.should_not eq(0)
      when_run.to_i.should eq(run_at.to_i)
    end
    
    it "can be cancelled" do
      run_at = Time.now.to_f + 0.5
      has_run = false
      runner = BackgroundQueue::ServerLib::ErrorTaskList::RunAt.new(run_at) {
        has_run = true
      }
      sleep(0.05)
      runner.cancel.should be_true
      runner.wait_for_run
      has_run.should be_false
    end
  end
end
