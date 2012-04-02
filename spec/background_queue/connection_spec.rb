require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
  
describe "Connection" do

  let(:server) { 
    svr = double('Server')
    svr.stub({:host=>:host, :port=>:port})
    svr
  }
  
  

  context "connecting" do
    
    subject { BackgroundQueue::Connection.new(:client, server) }
    
    it "can successfully connect" do
      TCPSocket.should_receive(:open).with(:host, :port) { :socket }
      subject.connect.should eq(true)
    end
    
    it "fails when no server to connect to" do
      TCPSocket.should_receive(:open).with(:host, :port) { raise "Unable to connect" }
      expect { subject.connect }.to raise_error(BackgroundQueue::ConnectionError, "Error Connecting to host:port: Unable to connect")
    end
    
    it "fails if connection times out" do
      Timeout.should_receive(:timeout).with(any_args) { raise Timeout::Error }  
      expect { subject.connect }.to raise_error(BackgroundQueue::ConnectionError, "Timeout Connecting to host:port")
    end
  end
  
  context "connected" do
    
    let(:socket) {  stub() } 
      
    subject { 
      s = BackgroundQueue::Connection.new(:client, server) 
      TCPSocket.should_receive(:open).with(:host, :port) { socket }
      s.connect
      s
    }
  
    context "sending data" do
      
      it "can send data successfully in one go" do
        buf = "some data"
        socket.should_receive(:write).with(buf) { buf.length }
        subject.send_data(buf).should eq(true)
      end
      
      it "can send data successfully in 3 goes" do
        buf = "12345678"
        socket.should_receive(:write).with("12345678") { 2 }
        socket.should_receive(:write).with("345678") { 3 }
        socket.should_receive(:write).with("678") { 3 }
        subject.send_data(buf).should eq(true)
      end
      
      it "fails when underlying network fails" do
        buf = "12345678"
        socket.should_receive(:write).with("12345678") { 2 }
        socket.should_receive(:write).with("345678") { raise "Socket Disconnected" }
        
        expect { subject.send_data(buf)}.to raise_error(BackgroundQueue::ConnectionError, "Error Sending to host:port: Socket Disconnected")
      end
      
      it "fails when command times out" do
        init_subject = subject #need to init the subject before forcing timeout
        Timeout.should_receive(:timeout).with(any_args) { raise Timeout::Error }  
        expect { init_subject.send_data("data")}.to raise_error(BackgroundQueue::ConnectionError, "Timeout Sending to host:port")
      end
    end
    
    context "sending with header" do
      
      let(:data) { "data"}
      let(:packed_data) { [1,4,data].pack("SLZ4") }
      
      it "can pack the header onto the data" do
        BackgroundQueue::Connection.add_header(data).should eq(packed_data)
      end
      
      it "can send data with header" do
        subject.should_receive(:send_data).with(packed_data) { true}
        subject.send_with_header(data).should eq(true)
      end
      
    end
    
    context "receiving data" do
      it "can receive data successfully in one go" do
        socket.should_receive(:recvfrom).with(4) { ["data", nil] }
        subject.receive_data(4).should eq("data")  
      end
      
      it "can receive data successfully in 3 goes" do
        socket.should_receive(:recvfrom).with(10) { ["0123", nil] }
        socket.should_receive(:recvfrom).with(6) { ["45", nil] }
        socket.should_receive(:recvfrom).with(4) { ["6789", nil] }
        subject.receive_data(10).should eq("0123456789")  
      end
      
      it "fails when underlying network fails" do
        socket.should_receive(:recvfrom).with(10) { ["0123", nil] }
        socket.should_receive(:recvfrom).with(6) { raise "Socket Disconnected" }
        expect { subject.receive_data(10)}.to raise_error(BackgroundQueue::ConnectionError, "Error Receiving 10 bytes from host:port: Socket Disconnected")
      end
      
      it "fails when response times out" do
        init_subject = subject #need to init the subject before forcing timeout
        Timeout.should_receive(:timeout).with(any_args) { raise Timeout::Error }  
        expect { init_subject.receive_data(10)}.to raise_error(BackgroundQueue::ConnectionError, "Timeout Receiving 10 bytes from host:port")
      end
    end
    
    context "receiving with header" do
      
      let(:data) { "data"}
      let(:packed_data) { [1,4,data].pack("SLZ4") }
      

      it "can receive data with header" do
        subject.should_receive(:receive_data).with(6) { packed_data[0,6] }
        subject.should_receive(:receive_data).with(4) { packed_data[6,4] }
        
        subject.receive_with_header().should eq(data)
      end
      
    end
  end
  
  
  context "sending command" do
    
    subject { BackgroundQueue::Connection.new(:client, server) }
    let(:send_command) { stub({:to_buf=>:data}) }

    it "can successfully send command" do
      
      subject.stub(:check_connected) { true }
      subject.should_receive(:send_with_header).with(:data) { true }
      subject.should_receive(:receive_with_header).with(no_args) { :receive_response }
      BackgroundQueue::Command.should_receive(:from_buf).with(:receive_response) { :command_response }
      
      subject.send_command(send_command).should eq(:command_response)
    end
    
    it "fails if unable to connect" do
      TCPSocket.should_receive(:open).with(:host, :port) { raise "Unable to connect" }
      expect {  subject.send_command(send_command)  }.to raise_error(BackgroundQueue::ConnectionError, "Error Connecting to host:port: Unable to connect")
    end
    
    it "fails if unable to send data" do
      subject.stub(:check_connected) { true }
      subject.should_receive(:send_with_header).with(:data) { raise BackgroundQueue::ConnectionError, "Send Error" }
      expect {  subject.send_command(send_command)  }.to raise_error(BackgroundQueue::ConnectionError, "Send Error")

    end
    
    it "fails if unable to recieve response" do
      subject.stub(:check_connected) { true }
      subject.should_receive(:send_with_header).with(:data) { true }
      subject.should_receive(:receive_with_header).with(no_args) { raise BackgroundQueue::ConnectionError, "Receive Error" }
      expect {  subject.send_command(send_command)  }.to raise_error(BackgroundQueue::ConnectionError, "Receive Error")
    end
  end

end
