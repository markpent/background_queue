require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::EventConnection do

  subject { BackgroundQueue::ServerLib::EventConnection.new(:server) }
  
  
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
      
    end
    
  end
  
  
  
end
