require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::JobRegistry do
 
  
  context "#register" do
    
    subject { BackgroundQueue::ServerLib::JobRegistry.new(3) }
    
    it "adds a job to the registry" do
      job = double("job1", :id=>"job1")
      subject.register(job)
      subject.__prv__lru.size.should eq(1)
    end
    
    it "updates existing job" do
      job = double("job1", :id=>"job1")
      job2 = double("job1", :id=>"job1")
      subject.register(job)
      subject.__prv__lru.size.should eq(1)
      subject.register(job2)
      subject.__prv__lru.size.should eq(1)
      subject.__prv__lru.get("job1").should be(job2)
    end
    
    it "expires jobs" do
      job = double("job1", :id=>"job1")
      job2 = double("job2", :id=>"job2")
      job3 = double("job3", :id=>"job3")
      job4 = double("job4", :id=>"job4")
      subject.register(job)
      subject.register(job2)
      subject.register(job3)
      subject.__prv__lru.size.should eq(3)
      subject.register(job4)
      subject.__prv__lru.size.should eq(3)
    end
  end
  
  context "#get_job" do
    
    subject { BackgroundQueue::ServerLib::JobRegistry.new(3) }
    
    it "moves job to start or lru" do
      job = double("job1", :id=>"job1")
      job2 = double("job2", :id=>"job2")
      job3 = double("job3", :id=>"job3")
      job4 = double("job4", :id=>"job4")
      
      subject.register(job)
      subject.register(job2)
      subject.register(job3)
      subject.__prv__lru.size.should eq(3)
      
      subject.get_job("job1").should be(job)
      subject.register(job4)
      subject.__prv__lru.size.should eq(3)
      subject.get_job("job1").should be(job)
      subject.get_job("job2").should be_nil
      
    end
  end
end
