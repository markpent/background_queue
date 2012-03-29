require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
  
describe "Client" do

  context "initializing" do
    it "loads from config path" do
      BackgroundQueue::Config.stub(:load_file).with(:path_that_exists) { BackgroundQueue::Config.new(:a, :b, :c) }
      bq_client = BackgroundQueue::Client.new(:path_that_exists)
      bq_client.config.server.should eq(:a)
    end
  end
  
  context "connecting" do
    
  end

end
