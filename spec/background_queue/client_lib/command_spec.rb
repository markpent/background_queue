require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue'

describe "Command" do

  context "add_task" do
    it "creates valid command" do
      cmd = BackgroundQueue::ClientLib::Command.add_task_command(:worker, :owner_id, :job_id, :task_id, 1, {:a=>:b}, {:c=>:d} )
      cmd.code.should eq(:add_task)
      cmd.options[:c].should eq(:d)
      cmd.args[:worker].should eq(:worker)
      cmd.args[:owner_id].should eq(:owner_id)
      cmd.args[:job_id].should eq(:job_id)
      cmd.args[:task_id].should eq(:task_id)
      cmd.args[:params][:a].should eq(:b)
      
    end
  end
  
  context "add_tasks" do
    it "creates valid command" do
      cmd = BackgroundQueue::ClientLib::Command.add_tasks_command(:worker, :owner_id, :job_id, [[:task1_id, {:a=>:b}], [:task2_id, {:e=>:f}]], 1, {:shared=>:param}, {:c=>:d} )
      cmd.code.should eq(:add_tasks)
      cmd.options[:c].should eq(:d)
      cmd.args[:worker].should eq(:worker)
      cmd.args[:owner_id].should eq(:owner_id)
      cmd.args[:job_id].should eq(:job_id)
      cmd.args[:shared_parameters][:shared].should eq(:param)
      cmd.args[:tasks].length.should eq(2)
      cmd.args[:tasks].first.length.should eq(2)
      cmd.args[:tasks].first[0].should eq(:task1_id)
      cmd.args[:tasks].first[1][:a].should eq(:b)
      cmd.args[:tasks].last.length.should eq(2)
      cmd.args[:tasks].last[0].should eq(:task2_id)
      cmd.args[:tasks].last[1][:e].should eq(:f)
    end
    
    it "fails if no tasks are defined" do
      expect {
       cmd = BackgroundQueue::ClientLib::Command.add_tasks_command(:worker, :owner_id, :job_id, [], 1, {:shared=>:param}, {:c=>:d} )
      }.to raise_exception(BackgroundQueue::InvalidCommand, "No Tasks In List")
    end
  end
  
  
  context "#get_status_command" do
    it "creates valid command" do
      cmd = BackgroundQueue::ClientLib::Command.get_status_command(:job_id,  {:c=>:d} )
      cmd.code.should eq(:get_status)
      cmd.options[:c].should eq(:d)
      cmd.args[:job_id].should eq(:job_id)
    end
  end
  
  
  #i cant see why this would be needed.... will add back if needed
  #context "remove_tasks" do
  #  it "creates valid command" do
  #    cmd = BackgroundQueue::ClientLib::Command.remove_tasks_command([:task1_id,:task2_id], {:c=>:d} )
  #    cmd.code.should eq(:remove_tasks)
  #    cmd.options[:c].should eq(:d)
  #    cmd.args[:tasks].length.should eq(2)
  #    cmd.args[:tasks][0].should eq(:task1_id)
  #    cmd.args[:tasks][1].should eq(:task2_id)
  #  end
  #  
  #  it "fails if no tasks are defined" do
  #    expect {
  #     cmd = BackgroundQueue::ClientLib::Command.remove_tasks_command([], {:c=>:d} )
  #    }.to raise_exception(BackgroundQueue::InvalidCommand, "No Tasks In List")
  #  end
  #end
  

end
