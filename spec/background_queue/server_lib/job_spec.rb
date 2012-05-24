require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::Job do

  subject { BackgroundQueue::ServerLib::Job.new(1, :parent) }
  let(:task) { SimpleTask.new(:owner_id, :job_id, :id, :priority, {}) }
  
  it "#add_item uses normal priority queue" do
    task.should_receive(:set_job).with(subject)
    BackgroundQueue::ServerLib::Job.any_instance.should_receive(:push).with(task).and_return(nil)
    subject.add_item(task)
  end
  
  it "#next_item uses normal priority queue" do
    BackgroundQueue::ServerLib::Job.any_instance.should_receive(:pop).and_return(:task)
    subject.next_item.should eq(:task)
  end
  
  context "#set_worker_status" do
    it "will update_finished_status if finished" do
      status = {:percent=>100.0}
      
      subject.should_receive(:update_finished_status).with(status)
      subject.set_worker_status(status)
    end
    
    it "will get running status and update it if not finished" do
      status = {:percent=>99.0}
      subject.should_receive(:get_running_status).with(status).and_return(:rstatus)
      subject.should_receive(:update_running_status).with(:rstatus, status)
      subject.set_worker_status(status)
    end
  end
  
  
  
  context "#get_running_status" do
    it "will register a new task if new" do
      status = {:task_id=>:tid}
      subject.should_receive(:register_running_status).with(status).and_return(:new_status)
      subject.get_running_status(status).should eq(:new_status)
    end
    
    it "will return an existing registered task" do
      status = {:task_id=>:tid}
      subject.get_running_status(status)[:task_id].should eq(:tid)
      subject.should_not_receive(:register_running_status)
      subject.get_running_status(status)[:task_id].should eq(:tid)
    end
  end
  
  context "#register_running_status" do
    it "will add a status to map and ordered array" do
      status = {:task_id=>:some_status}
      subject.register_running_status(status)[:task_id].should eq(:some_status)
      subject.running_status[:some_status][:task_id].should eq(:some_status)
      subject.running_ordered_status.should have(1).item
      subject.running_ordered_status[0][:task_id].should eq(:some_status)
    end
    
    it "will not add to ordered array if excluded from count" do
      status = {:task_id=>:some_status, :exclude=>true}
      subject.register_running_status(status)[:task_id].should eq(:some_status)
      subject.running_status[:some_status][:task_id].should eq(:some_status)
      subject.running_ordered_status.should have(0).items
    end
  end
  
  context "#deregister_running_status" do
    it "will remove the status from the map and the ordered array" do
      status = {:task_id=>:tid}
      status2 = {:task_id=>:tid2}
      subject.running_status[:tid] = status
      subject.running_ordered_status << status
      subject.running_status[:tid2] = status2
      subject.running_ordered_status << status2
      subject.deregister_running_status(:tid)
      subject.running_status[:tid].should be_nil
      subject.running_ordered_status.should have(1).item
      subject.running_ordered_status.first.should be(status2)
      
      subject.deregister_running_status(:tid2)
      subject.running_ordered_status.should have(0).items
      
    end
  end
  
  context "#update_finished_status" do
    it "will remove the task as running and increment the finished count" do
      status = {:task_id=>:tid, :percent=>100.0}
      subject.should_receive(:deregister_running_status).with(:tid).and_return({:exclude=>false})
      subject.update_finished_status(status)
      subject.completed_tasks.should eq(1)
      subject.completed_counted_tasks.should eq(1)
    end
    
    it "will remove the task as running and increment the finished count but not counted" do
      status = {:task_id=>:tid, :percent=>100.0, :exclude=>true}
      subject.should_receive(:deregister_running_status).with(:tid).and_return({:exclude=>true})
      subject.update_finished_status(status)
      subject.completed_tasks.should eq(1)
      subject.completed_counted_tasks.should eq(0)
    end
    
    it "will do nothing if the task has not been registered as running" do
      status = {:task_id=>:tid, :percent=>100.0}
      subject.update_finished_status(status)
      subject.completed_tasks.should eq(0)
    end
  end
  
  
  
  context "#update_running_status" do
    it "will update the comment and percent of the task" do
      status = {:task_id=>:tid, :percent=>55.0, :caption=>"hello"}
      rstatus = {:task_id=>:tid, :percent=>40.0, :caption=>"bye"}
      subject.should_receive(:update_running_percent)
      subject.update_running_status(rstatus, status)
      rstatus[:percent].should eq(55.0)
      rstatus[:caption].should eq("hello")
      
    end
  end
  
  context "#update_running_percent" do
    it "will get the total percent through of the running tasks and set_current_status" do
      status = {:task_id=>:tid, :percent=>90.0}
      status2 = {:task_id=>:tid2, :percent=>22.0}
      subject.running_ordered_status << status
      subject.running_ordered_status << status2
      subject.should_receive(:set_running_percent).with(1.12, 1.12)
      subject.update_running_percent
    end
    
  end
  
  context "#set_running_percent" do
    context "without excluded" do
      before do
        @status = {:task_id=>:tid, :percent=>90.0}
        @status2 = {:task_id=>:tid2, :percent=>22.0}
        @status3 = {:task_id=>:tid3, :percent=>22.0}
        subject.running_ordered_status << @status
        subject.running_ordered_status << @status2
        subject.running_ordered_status << @status3
      end
      
      it "will set status to the first status if the running percent is 0" do
        subject.set_running_percent(0.0, 0.0)
        subject.current_running_status.should be(@status)
      end
      
      it "will set status to the first status if the running percent is < 1" do
        subject.set_running_percent(0.9, 0.9)
        subject.current_running_status.should be(@status)
      end
      
      it "will set status to the second status if the running percent is < 2 > 1 " do
        subject.set_running_percent(1.2, 1.2)
        subject.current_running_status.should be(@status2)
      end
      
      it "will set status to the second status if the running percent is < 3 > 2 " do
        subject.set_running_percent(2.99, 2.99)
        subject.current_running_status.should be(@status3)
      end
    end
    
    context "with excluded" do
      it "will use the current_running_excluded_status if there are no running_ordered_status" do
        status = {:task_id=>:tid, :percent=>55.0, :caption=>"hello", :exclude=>true}
        subject.set_worker_status(status)
        subject.set_running_percent(0, 0.55)
        subject.current_running_status[:task_id].should eq(:tid)
      end
      
      it "will not use the current_running_excluded_status if there are running_ordered_status" do
        subject.set_worker_status({:task_id=>:tid, :percent=>55.0, :caption=>"hello", :exclude=>true})
        subject.set_worker_status({:task_id=>:tid2, :percent=>55.0, :caption=>"hello2", :exclude=>false})
        subject.set_running_percent(0.55, 1.1)
        subject.current_running_status[:task_id].should eq(:tid2)
      end
      
      it "will not use the current_running_excluded_status if there are running_ordered_status even if at 0" do
        subject.set_worker_status({:task_id=>:tid, :percent=>55.0, :caption=>"hello", :exclude=>true})
        subject.set_worker_status({:task_id=>:tid2, :percent=>55.0, :caption=>"hello2", :exclude=>false})
        subject.set_running_percent(0.0, 1.1)
        subject.current_running_status[:task_id].should eq(:tid2)
      end
    end
  end
  
  context "#get_running_task_progress" do
    it "will start at 0%" do
      
    end
  end
end
