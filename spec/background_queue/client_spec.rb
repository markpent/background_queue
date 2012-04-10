require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
  
describe "Client" do

  context "initializing" do
    it "loads from config path" do
      BackgroundQueue::ClientLib::Config.stub(:load_file).with(:path_that_exists) { BackgroundQueue::ClientLib::Config.new(:a, :b, :c) }
      bq_client = BackgroundQueue::Client.new(:path_that_exists)
      bq_client.config.server.should eq(:a)
    end
  end
  
  context "initialized" do
    subject { 
      BackgroundQueue::ClientLib::Config.stub(:load_file).with(:path_that_exists) { 
        BackgroundQueue::ClientLib::Config.new(:primary_server, [:failover_1, :failover_2], :memcache_server) 
      }
      BackgroundQueue::Client.new(:path_that_exists) 
    }
    
    context "sending a command" do
      it "can send a command to a server" do
        BackgroundQueue::ClientLib::Connection.any_instance.should_receive(:send_command).with(:command) { true }
        subject.__prv__send_command_to_server(:command, :primary_server).should eq(true)
      end
      
      it "can succeed first time" do
        subject.should_receive(:send_command_to_server).with(:command, :primary_server) { true }
        subject.__prv__send_command(:command).should eq(true)
      end
      
      it "can use failover server if main server fails" do
        subject.should_receive(:send_command_to_server).with(:command, :primary_server) { raise BackgroundQueue::ClientLib::ConnectionError, "Primary" }
        subject.should_receive(:send_command_to_server).with(:command, :failover_1) { true }
        subject.__prv__send_command(:command).should eq(true)
      end
      
      it "can use second failover server if needed" do
        subject.should_receive(:send_command_to_server).with(:command, :primary_server) { raise BackgroundQueue::ClientLib::ConnectionError, "Primary" }
        subject.should_receive(:send_command_to_server).with(:command, :failover_1) { raise BackgroundQueue::ClientLib::ConnectionError, "Failure 1" }
        subject.should_receive(:send_command_to_server).with(:command, :failover_2) { true }
        subject.__prv__send_command(:command).should eq(true)
      end
      
      it "throws an exception if all connections fail" do
        subject.should_receive(:send_command_to_server).with(:command, :primary_server) { raise BackgroundQueue::ClientLib::ConnectionError, "Primary" }
        subject.should_receive(:send_command_to_server).with(:command, :failover_1) { raise BackgroundQueue::ClientLib::ConnectionError, "Failure 1" }
        subject.should_receive(:send_command_to_server).with(:command, :failover_2) { raise BackgroundQueue::ClientLib::ConnectionError, "Failure 2" }
        expect { subject.__prv__send_command(:command) }.to raise_error(BackgroundQueue::ClientException, "Primary, Attempt 2: Failure 1, Attempt 3: Failure 2")
      end
    end
    
    context "single call commands" do
      before do
        subject.should_receive(:send_command).with(anything) { true }
      end
      it "can build and send an add task command" do
        subject.add_task(:worker, :owner_id, :job_id, :task_id, {}, {} ).should eq(true)
      end
      
      it "can build and send an add tasks command" do
        subject.add_tasks(:worker, :owner_id, :job_id, :tasks, {}, {} ).should eq(true)
      end
      
      it "can build and send a remove task command" do
        subject.remove_tasks(:tasks, {}).should eq(true)
      end
      
    end
  end
end
