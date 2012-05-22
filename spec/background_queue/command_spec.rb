require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'background_queue'

describe "Command" do

  
  context "serialization" do
    it "can reload from serialized format" do
      cmd = BackgroundQueue::ClientLib::Command.add_task_command(:worker, :owner_id, :job_id, :task_id, 1, {:a=>:b}, {:c=>:d} )
      serialized = cmd.to_buf

      cmd = BackgroundQueue::Command.from_buf(serialized)
      
      cmd.code.should eq(:add_task)
      cmd.options[:c].should eq('d')
      cmd.args[:worker].should eq('worker')
      cmd.args[:owner_id].should eq('owner_id')
      cmd.args[:job_id].should eq('job_id')
      cmd.args[:task_id].should eq('task_id')
      cmd.args[:params]['a'].should eq('b')
      
    end
    
    it "fails when loading from invalid json" do
      expect { BackgroundQueue::Command.from_buf("{sdf, sdfsdf}")}.to raise_exception(BackgroundQueue::InvalidCommand)
    end
    
    it "fails when loading from missing data in json" do
      expect { BackgroundQueue::Command.from_buf('{"a": "b"}')}.to raise_exception(BackgroundQueue::InvalidCommand, "Error loading command from buffer: Missing 'c' (code)")
    end
    
  end

end
