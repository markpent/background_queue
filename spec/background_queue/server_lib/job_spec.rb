require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::Job do

  subject { BackgroundQueue::ServerLib::Job.new(1, :parent) }
  let(:task) { SimpleTask.new(:owner_id, :job_id, :id, :priority, {}) }
  
  it "#add_item uses normal priority queue" do
    task.should_receive(:set_job).with(subject)
    task.should_receive(:synchronous?).and_return(false)
    BackgroundQueue::ServerLib::Job.any_instance.should_receive(:push).with(task).and_return(nil)
    subject.add_item(task)
  end
  
  it "#next_item uses normal priority queue" do
    BackgroundQueue::ServerLib::Job.any_instance.should_receive(:pop).and_return(:task)
    subject.next_item.should eq(:task)
  end
  
  context "#add_item" do
    it "will initialise the status caption if requested" do
      task_with_status = SimpleTask.new(:owner_id, :job_id, :id, :priority, {:initial_progress_caption=>"test"})
      subject.add_item(task_with_status)
      subject.get_current_progress[:caption].should eq("test")
    end
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
    
    it "will update meta data if :meta is passed in" do
      status = {:meta=>:meta}
      subject.should_receive(:update_status_meta).with(:meta)
      subject.set_worker_status(status)
    end
  end
  
  context "#update_status_meta" do
    it "will add notices to notices meta list" do
      subject.update_status_meta({:notice=>"hello"})
      subject.get_current_progress[:notice].should eq(["hello"])
      subject.update_status_meta({:notice=>"world"})
      subject.get_current_progress[:notice].should eq(["hello", "world"])
    end
    it "will add warnings to warnings meta list" do
      subject.update_status_meta({:warning=>"hello"})
      subject.get_current_progress[:warning].should eq(["hello"])
      subject.update_status_meta({:warning=>"world"})
      subject.get_current_progress[:warning].should eq(["hello", "world"])
    end
    it "will add errors to errors meta list" do
      subject.update_status_meta({:error=>"hello"})
      subject.get_current_progress[:error].should eq(["hello"])
      subject.update_status_meta({:error=>"world"})
      subject.get_current_progress[:error].should eq(["hello", "world"])
    end
    it "will add meta data to meta entry" do
      subject.update_status_meta({:meta=>{:a=>"b"}})
      subject.get_current_progress[:meta].should eq({:a=>"b"})
      subject.update_status_meta({:meta=>{:c=>"d"}})
      subject.get_current_progress[:meta].should eq({:a=>"b", :c=>"d"})
      subject.update_status_meta({:meta=>{:c=>"e"}})
      subject.get_current_progress[:meta].should eq({:a=>"b", :c=>"e"})
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
    
    #it "will not add to ordered array if excluded from count" do
    #  status = {:task_id=>:some_status, :exclude=>true}
    #  subject.register_running_status(status)[:task_id].should eq(:some_status)
    #  subject.running_status[:some_status][:task_id].should eq(:some_status)
    #  subject.running_ordered_status.should have(0).items
    #end
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
    
    it "will increment the completed weighted tasks" do
      status = {:task_id=>:tid, :percent=>100.0, :exclude=>true, :weight=>5.0}
      subject.should_receive(:deregister_running_status).with(:tid).and_return({:exclude=>true, :weight=>5.0})
      subject.update_finished_status(status)
      subject.completed_tasks.should eq(1)
      subject.completed_counted_tasks.should eq(0)
      subject.completed_weighted_percent.should eq(5.0)
      subject.completed_weighted_tasks.should eq(1)
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
      subject.should_receive(:set_running_percent).with(1.12, 1.12, 1.12, 0.0)
      subject.update_running_percent
    end
    
    it "will get the running percent of weighted tasks" do
      status = {:task_id=>:tid, :percent=>90.0}
      status2 = {:task_id=>:tid2, :percent=>22.0}
      status3 = {:task_id=>:tid2, :percent=>20.0, :weight=>5.0}
      status4 = {:task_id=>:tid2, :percent=>50.0, :weight=>10.0}
      subject.running_ordered_status << status
      subject.running_ordered_status << status2
      subject.running_ordered_status << status3
      subject.running_ordered_status << status4
      subject.should_receive(:set_running_percent).with(1.12, 1.12, 1.82, 0.06)
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
        subject.set_running_percent(0.0, 0.0, 0.0, 0.0)
        subject.current_running_status.should be(@status)
      end
      
      it "will set status to the first status if the running percent is < 1" do
        subject.set_running_percent(0.9, 0.9, 0.9, 0.0)
        subject.current_running_status.should be(@status)
      end
      
      it "will set status to the second status if the running percent is < 2 > 1 " do
        subject.set_running_percent(1.2, 1.2, 1.2, 0.0)
        subject.current_running_status.should be(@status2)
      end
      
      it "will set status to the second status if the running percent is < 3 > 2 " do
        subject.set_running_percent(2.99, 2.99, 2.99, 0.0)
        subject.current_running_status.should be(@status3)
      end

    end
    
    context "with excluded" do
      it "will use the current_running_excluded_status if there are no running_ordered_status" do
        status = {:task_id=>:tid, :percent=>55.0, :caption=>"hello", :exclude=>true}
        subject.set_worker_status(status)
        subject.set_running_percent(0, 0.55, 0.55, 0.0)
        subject.current_running_status[:task_id].should eq(:tid)
      end
      
      it "will not use the current_running_excluded_status if there are running_ordered_status" do
        subject.set_worker_status({:task_id=>:tid, :percent=>55.0, :caption=>"hello", :exclude=>true})
        subject.set_worker_status({:task_id=>:tid2, :percent=>55.0, :caption=>"hello2", :exclude=>false})
        subject.set_running_percent(0.55, 1.1, 1.1, 0.0)
        subject.current_running_status[:task_id].should eq(:tid2)
      end
      
      it "will not use the current_running_excluded_status if there are running_ordered_status even if at 0" do
        subject.set_worker_status({:task_id=>:tid, :percent=>55.0, :caption=>"hello", :exclude=>true})
        subject.set_worker_status({:task_id=>:tid2, :percent=>55.0, :caption=>"hello2", :exclude=>false})
        subject.set_running_percent(0.0, 1.1, 1.1, 0.0)
        subject.current_running_status[:task_id].should eq(:tid2)
      end
    end
  end
  
  context "#get_current_progress_percent" do
    it "will start at 0%" do
      subject.get_current_progress_percent.should eq(0)
    end
    
    it "will use single task percent" do
      subject.stub(:total_tasks=>1, :completed_tasks=>0, :running_percent=>0.5)
      subject.get_current_progress_percent.should eq(50.0)
    end
    
    it "will track multiple tasks" do
      subject.stub(:total_tasks=>4, :completed_tasks=>2, :running_percent=>0.10)
      #50% + 10/4%
      subject.get_current_progress_percent.should eq(52.5)
    end
    
    it "will track weighted tasks" do
      subject.stub(:total_tasks=>4, :completed_tasks=>2, :running_percent=>0.10, :total_weighted_percent=>40.0, :completed_weighted_percent=>20.0, :running_percent_weighted=>0.1)
      #weighted_percent = 40%
      #unweighted_percent = 60%
      #completed percent = 2/4 = 50% of unweighted_percent = 30%
      #running percent = 10% of 1 task (25% of 60%) = 1.5%
      #completed_weighted_percent = 20%
      #running weighted_percent = 10%
      #total = 61.5%
      subject.get_current_progress_percent.should eq(61.5)
      
    end
    
  end
  
  context "#get_current_progress_caption" do
    it "will start blank" do
      subject.get_current_progress_caption.should eq("")
    end
    
    it "will use the caption from the designated running task" do
      subject.stub(:current_running_status=>{:caption=>:cappy})
      subject.get_current_progress_caption.should eq(:cappy)
    end
    
    it "will add a counter if the current task is counted, and the total counted tasks > 1" do
      subject.stub(:current_running_status=>{:caption=>'cappy'}, :total_counted_tasks=>2, :completed_counted_tasks=>0)
      subject.get_current_progress_caption.should eq('cappy (1/2)')
    end
    
    it "will not add a counter if the current task is not counted" do
      status = {:caption=>'cappy', :exclude=>true}
      subject.stub(:current_running_status=>status, :total_counted_tasks=>2, :completed_counted_tasks=>0)
      subject.get_current_progress_caption.should eq('cappy')
    end
    
    it "will not add a counter if the total counted tasks is 1" do
      status = {:caption=>'cappy'}
      subject.stub(:current_running_status=>status, :total_counted_tasks=>1, :completed_counted_tasks=>0)
      subject.get_current_progress_caption.should eq('cappy')
    end
  end
  
  context "integration" do
    it "will track progress" do
      task0 = BackgroundQueue::ServerLib::Task.new(:owner_id, :job_id, :id0, 1, :worker, {}, {:exclude=>true})
      subject.add_item(task0)
      task1 = BackgroundQueue::ServerLib::Task.new(:owner_id, :job_id, :id1, 1, :worker, {}, {})
      subject.add_item(task1)
      task2 = BackgroundQueue::ServerLib::Task.new(:owner_id, :job_id, :id2, 1, :worker, {}, {})
      subject.add_item(task2)
      task3 = BackgroundQueue::ServerLib::Task.new(:owner_id, :job_id, :id3, 1, :worker, {}, {})
      subject.add_item(task3)
      
      subject.total_tasks.should eq(4)
      subject.total_counted_tasks.should eq(3)
      
      subject.get_current_progress[:percent].should eq(0.0)
      
      task = subject.next_item
      subject.get_current_progress[:percent].should eq(0.0)
      
      task.set_worker_status(:percent=>10.0, :caption=>"loading")
      subject.current_running_status[:task_id].should eq(:id0)
      subject.running_percent.should eq(0.1)
      
      subject.get_current_progress[:percent].should eq(2.5)
      subject.get_current_progress[:caption].should eq("loading")
      
      task.set_worker_status(:percent=>50.0, :caption=>"loading")
      
      subject.get_current_progress[:percent].should eq(12.5)
      
      task.set_worker_status(:percent=>100.0, :caption=>"loading")
      
      subject.get_current_progress[:percent].should eq(25.0)
      
      task1 = subject.next_item
      task2 = subject.next_item
      
      task1.set_worker_status(:percent=>10.0, :caption=>"task1")
      task2.set_worker_status(:percent=>10.0, :caption=>"task2")
      
      #25% + 20%/4 = 30%  
      subject.get_current_progress[:percent].should eq(30.0)
      subject.get_current_progress[:caption].should eq("task1 (1/3)")
      
      task1.set_worker_status(:percent=>50.0, :caption=>"task1")
      #25% + 60%/4 = 30%  
      subject.get_current_progress[:percent].should eq(40.0)
      subject.get_current_progress[:caption].should eq("task1 (1/3)")
      
      task1.set_worker_status(:percent=>70.0, :caption=>"task1")
      task2.set_worker_status(:percent=>30.0, :caption=>"task2")
      
      #25% + 100%/4 = 50%  
      subject.get_current_progress[:percent].should eq(50.0)
      subject.get_current_progress[:caption].should eq("task2 (2/3)")
      
      task1.set_worker_status(:percent=>100.0, :caption=>"task1")

      
      #25% + 130%/4 = 57.5%  
      subject.get_current_progress[:percent].should eq(57.5)
      subject.get_current_progress[:caption].should eq("task2 (2/3)")
      
      task3 = subject.next_item
      
      #50% + 50%/4 = 62.5
      task2.set_worker_status(:percent=>50.0, :caption=>"task2")
      subject.get_current_progress[:percent].should eq(62.5)
      subject.get_current_progress[:caption].should eq("task2 (2/3)")
      
      #50% + 100%/4 = 75%
      task3.set_worker_status(:percent=>50.0, :caption=>"task3")
      subject.get_current_progress[:percent].should eq(75.0)
      subject.get_current_progress[:caption].should eq("task3 (3/3)")
      
      #75% + 50%/4 = 87.5%
      task2.set_worker_status(:percent=>100.0, :caption=>"task2")
      subject.get_current_progress[:percent].should eq(87.5)
      subject.get_current_progress[:caption].should eq("task3 (3/3)")
      
      #75% + 50%/4 = 87.5%
      task3.set_worker_status(:percent=>100.0, :caption=>"task3")
      subject.get_current_progress[:percent].should eq(100.0)
      subject.get_current_progress[:caption].should eq("task3 (3/3)")
      
    end
    
    it "will track weighted tasks" do
      task0 = BackgroundQueue::ServerLib::Task.new(:owner_id, :job_id, :id0, 1, :worker, {}, {:exclude=>true, :weight=>20.0})
      subject.add_item(task0)
      
      subject.total_weighted_percent.should eq(20.0)
      subject.total_weighted_tasks.should eq(1)
      
      subject.get_current_progress[:percent].should eq(0.0)
      
      task = subject.next_item
      subject.get_current_progress[:percent].should eq(0.0)
      
      task.set_worker_status(:percent=>10.0, :caption=>"loading")
      subject.current_running_status[:task_id].should eq(:id0)
      subject.running_percent_weighted.should eq(0.02)
      subject.running_percent.should eq(0.0)
      subject.total_weighted_tasks.should eq(1)
      subject.total_tasks.should eq(1)
      subject.completed_weighted_tasks.should eq(0.0)
      subject.completed_tasks.should eq(0.0)
      
      subject.get_current_progress[:percent].should eq(2.0)
      subject.get_current_progress[:caption].should eq("loading")

      task1 = BackgroundQueue::ServerLib::Task.new(:owner_id, :job_id, :id1, 1, :worker, {}, {})
      subject.add_item(task1)
      task2 = BackgroundQueue::ServerLib::Task.new(:owner_id, :job_id, :id2, 1, :worker, {}, {})
      subject.add_item(task2)
      task3 = BackgroundQueue::ServerLib::Task.new(:owner_id, :job_id, :id3, 1, :worker, {}, {})
      subject.add_item(task3)
      
      task5 = BackgroundQueue::ServerLib::Task.new(:owner_id, :job_id, :id4, 1, :worker, {}, {:exclude=>true, :weight=>20.0})
      subject.add_item(task5)
      
      subject.get_current_progress[:percent].should eq(2.0)
      subject.get_current_progress[:caption].should eq("loading")
      
      task.set_worker_status(:percent=>50.0, :caption=>"loading")
      
      subject.get_current_progress[:percent].should eq(10.0)
      subject.get_current_progress[:caption].should eq("loading")
      
      task1 = subject.next_item
      task2 = subject.next_item
      
      task1.set_worker_status(:percent=>10.0, :caption=>"task1")
      task2.set_worker_status(:percent=>10.0, :caption=>"task2")
      
      #10% + 10% of 20% + 10% of 20% = 14%
      
      
      subject.current_running_status[:task_id].should eq(:id0)
      subject.running_percent_weighted.should eq(0.1)
      subject.running_percent.should eq(0.2)
      subject.total_weighted_tasks.should eq(2)
      subject.total_tasks.should eq(5)
      subject.completed_weighted_tasks.should eq(0.0)
      subject.completed_tasks.should eq(0.0)
      
      subject.get_current_progress[:percent].should eq(14.0)
      subject.get_current_progress[:caption].should eq("loading")
      
      task1.set_worker_status(:percent=>80.0, :caption=>"task1")
      #the task will now switch over to the next running task...
      subject.current_running_status[:task_id].should eq(:id1)
      subject.get_current_progress[:caption].should eq("task1 (1/3)")
      
      #10% + 10% of 20% + 80% of 20% = 28%
      subject.get_current_progress[:percent].should eq(28.0)
      
      #finish first weighted task
      task.set_worker_status(:percent=>100.0, :caption=>"loaded")
      subject.running_percent_weighted.should eq(0.0)
      subject.running_percent.should eq(0.9)
      subject.total_weighted_tasks.should eq(2)
      subject.total_tasks.should eq(5)
      subject.completed_weighted_tasks.should eq(1)
      subject.completed_tasks.should eq(1)
      subject.completed_counted_tasks.should eq(0)
      subject.completed_weighted_percent.should eq(20.0)
      
      #20% + 10% of 20% + 80% of 20% = 38%
      subject.get_current_progress[:caption].should eq("task1 (1/3)")
      subject.get_current_progress[:percent].should eq(38.0)
      
      task2.set_worker_status(:percent=>30.0, :caption=>"task2")
      #the task will now switch over to the next running task...
      subject.current_running_status[:task_id].should eq(:id2)
      subject.get_current_progress[:caption].should eq("task2 (2/3)")
      
      task1.set_worker_status(:percent=>100.0, :caption=>"task1")
      subject.get_current_progress[:caption].should eq("task2 (2/3)")
      
      task2.set_worker_status(:percent=>100.0, :caption=>"task2")
      subject.get_current_progress[:caption].should eq("task2 (3/3)")
      
      #20% + 100% of 20% + 100% of 20% = 60%
      #subject.get_current_progress[:percent].should eq(60.0)
      
      task3 = subject.next_item
      task3.set_worker_status(:percent=>100.0, :caption=>"task3")
      subject.get_current_progress[:caption].should eq("task3 (3/3)")
      subject.get_current_progress[:percent].should eq(80.0)
      
      task4 = subject.next_item
      task4.set_worker_status(:percent=>50.0, :caption=>"task4")
      subject.get_current_progress[:caption].should eq("task4")
      subject.get_current_progress[:percent].should eq(90.0)
      
      task4.set_worker_status(:percent=>100.0, :caption=>"task4")
      subject.get_current_progress[:caption].should eq("task4")
      subject.get_current_progress[:percent].should eq(100.0)
    end
    
  end
end
