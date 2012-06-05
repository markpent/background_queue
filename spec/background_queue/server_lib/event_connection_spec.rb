require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::EventConnection do

  subject { 
    s = BackgroundQueue::ServerLib::EventConnection.new(:something)
    s.post_init
    s
  }
  
  
  let(:data) { [1, 20, "12345678901234567890"].pack("SLZ20")}
  
  context "#receive_data" do
    it "can handle a packet in 1 call" do
      subject.should_receive(:process_data).with("12345678901234567890")
      subject.receive_data(data)
    end
    
    it "can handle the header in 2 calls" do
      subject.should_receive(:process_data).with("12345678901234567890")
      subject.receive_data(data.slice!(0, 2))
      subject.receive_data(data.slice!(0, 4))
      subject.receive_data(data)
    end
    
    it "can handle the body in 2 calls" do
      subject.should_receive(:process_data).with("12345678901234567890")
      subject.receive_data(data.slice!(0, 6))
      subject.receive_data(data.slice!(0, 4))
      subject.receive_data(data)
    end
    
    it "can handle the packets crossing header/body boundry" do
      subject.should_receive(:process_data).with("12345678901234567890")
      subject.receive_data(data.slice!(0, 4))
      subject.receive_data(data.slice!(0, 10))
      subject.receive_data(data)
    end
    
    it "will error if the version is wrong" do
      expect { subject.receive_data("ABCDEFG") }.to raise_exception("Invalid header version: 16961")
    end
  end
  
  context "#process_data" do
    it "will convert the data to a json object" do
      BackgroundQueue::Command.should_receive(:from_buf).with("{'a':'b'}").and_return(:command)
      subject.should_receive(:process_command).with(:command).and_return(:result)
      subject.should_receive(:send_result).with(:result)
      subject.process_data("{'a':'b'}")
    end
    
    it "will return an error if the json is invalid" do
      subject.should_receive(:send_error)
      subject.process_data("{sdf, sdfsdf}")
    end
    
  end
  
  context "#process_command" do
    it "will call process_add_task_cmd if cmd is add_task" do
      cmd = double("command", :code=>'add_task')
      subject.should_receive(:process_add_task_command).with(cmd).and_return(:result)
      subject.process_command(cmd).should eq(:result)
    end
    
    it "will call process_add_tasks_command if cmd is add_tasks" do
      cmd = double("command", :code=>'add_tasks')
      subject.should_receive(:process_add_tasks_command).with(cmd).and_return(:result)
      subject.process_command(cmd).should eq(:result)
    end
    
    it "will call process_remove_tasks_command if cmd is remove_tasks" do
      cmd = double("command", :code=>'remove_tasks')
      subject.should_receive(:process_remove_tasks_command).with(cmd).and_return(:result)
      subject.process_command(cmd).should eq(:result)
    end
    
    it "will raise an error if unknown task" do
      cmd = double("command", :code=>'dunno')
      expect { subject.process_command(cmd).should eq(:result) }.to raise_exception('Unknown command: dunno')
    end
  end
  
  context "#send_result" do
    it "will serialize the result to a json string and send" do
      cmd = BackgroundQueue::Command.new('a', {}, {})
      subject.should_receive(:send).with(cmd.to_buf)
      subject.send_result(cmd)
    end
  end
  
  context "#send_error" do
    it "will wrap the error into a command and call send_result" do
      BackgroundQueue::Command.should_receive(:new).with(:error, {}, {:message=>"error"}).and_return(:command)
      subject.should_receive(:send_result).with(:command)
      subject.send_error("error")
    end
  end
  
  context "#send" do
    it "will add a header to the data and call send_data" do
      data = [1,4,"data"].pack("SLZ4")
      subject.should_receive(:send_data).with(data)
      subject.send("data")
    end
  end
  
  context "#process_add_task_command" do
    it "builds a task from the command and adds it to the queue" do
      
      server = double("server", :task_queue=>double('task_queue'))
      server.task_queue.should_receive(:add_task).with(:task)
      
      command = BackgroundQueue::Command.new(:add_task, {}, {'owner_id'=>:owner_id, :job_id=>:job_id, 'task_id'=>:task_id, :priority=>:priority, :params=>:params  } )
      
      BackgroundQueue::ServerLib::Task.should_receive(:new).with(:owner_id, :job_id, :task_id, :priority, :params, command.options).and_return(:task)
      
      
      subject.server = server
      subject.process_add_task_command(command).code.should eq(:result)
    end
    
  end
  
  
  context "#process_add_tasks_command" do
    it "builds a set of tasks from the command and adds them to the queue" do
      
      server = double("server", :task_queue=>double('task_queue'))
      server.task_queue.should_receive(:add_task).with(:task1)
      server.task_queue.should_receive(:add_task).with(:task2)
      
      command = BackgroundQueue::Command.new(:add_tasks, {}, {'owner_id'=>:owner_id, :job_id=>:job_id, :tasks=>[[:task1_id, {:a=>:b}], [:task2_id, {:e=>:f}]], :priority=>:priority, :params=>:params, :shared_parameters=>{:shared=>:params}  } )
      
      BackgroundQueue::ServerLib::Task.should_receive(:new).with(:owner_id, :job_id, :task1_id, :priority, {:a=>:b, :shared=>:params}, command.options).and_return(:task1)
      BackgroundQueue::ServerLib::Task.should_receive(:new).with(:owner_id, :job_id, :task2_id, :priority, {:e=>:f, :shared=>:params}, command.options).and_return(:task2)
      
      subject.server = server
      subject.process_add_tasks_command(command).code.should eq(:result)
    end
    
  end
  
  
  
  
  
end
