require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::Task do

  subject { BackgroundQueue::ServerLib::Task.new(:owner_id, :job_id, :id, :priority, :worker, :params, {}) }
  
  context "#set_worker_status" do
    it "calls the jobs set_worker_status" do
      job = double("job")
      status = {}
      job.should_receive(:set_worker_status).with({:task_id=>:id, :exclude=>false}).and_return(:something)
      subject.set_job(job)
      subject.set_worker_status(status).should eq(:something)
    end
  end
  
  
end
