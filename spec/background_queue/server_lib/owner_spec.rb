require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::Owner do

  it_behaves_like "a queue registry" do
    let(:new_instance) { BackgroundQueue::ServerLib::Owner.new(1) }
  end
  
  context "callbacks" do
    
    subject { BackgroundQueue::ServerLib::Owner.new(1) }
    
    it "gets the job_id from tasks" do
      subject.__prv__get_queue_id_from_item(SimpleTask.new(:owner_id, :job_id, :task_id, 3)).should eq(:job_id)
    end
    
    it "calls add_item to add items to jobs" do
      BackgroundQueue::ServerLib::Job.any_instance.should_receive(:add_item).with(:item)
      subject.__prv__add_item_to_queue(BackgroundQueue::ServerLib::Job.new(1), :item)
    end
    
    it "specifies the job class as its queue class" do
      subject.class.queue_class.should eq(BackgroundQueue::ServerLib::Job)
    end
  end
end
