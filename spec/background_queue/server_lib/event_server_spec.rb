require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::EventServer do

  let(:server) { double("server", :config=>double("config", :address=>double("address", :host=>:host, :port=>:port))) }
  subject { BackgroundQueue::ServerLib::EventServer.new(server) }
  
  
  context "#start" do
    it "starts the event machine" do
      
      con=double("conection")
      con.should_receive("server=".intern).with(server)
      EventMachine.should_receive(:run).and_yield
      EventMachine.should_receive(:start_server).with(:host, :port, BackgroundQueue::ServerLib::EventConnection).and_yield(con)
      
      subject.start
    end
  end

  
end
