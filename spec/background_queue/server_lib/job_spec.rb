require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::Job do

  subject { BackgroundQueue::ServerLib::Job.new(1, :parent) }
  
  it "#add_item uses normal priority queue" do
    task = double("task")
    task.should_receive(:set_job).with(subject)
    BackgroundQueue::ServerLib::Job.any_instance.should_receive(:push).with(task).and_return(nil)
    subject.add_item(task)
  end
  
  it "#next_item uses normal priority queue" do
    BackgroundQueue::ServerLib::Job.any_instance.should_receive(:pop).and_return(:task)
    subject.next_item.should eq(:task)
  end
end
