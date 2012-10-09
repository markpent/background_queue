require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_worker'


describe BackgroundQueue::Worker::Base do

  let(:logger) {
    l = double("logger")
    l.stub(:debug)
    l.stub(:info)
    l.stub(:error)
    l.stub(:warn)
    l
  }

  let(:env) {
    double("env", :logger=>logger)
  }
  
  context "#set_progress" do
    it "will serialize the progress" do
      subject.set_environment(env)
      env.should_receive(:send_data).with({:caption=>"TEST", :percent=>15.1}.to_json)
      subject.set_progress("TEST", 15.1)
    end
  end
  
  context "#add_progress_meta" do
    it "will serialize the meta" do
      subject.set_environment(env)
      env.should_receive(:send_data).with({:meta=>{:a=>"b"}}.to_json)
      subject.add_progress_meta(:a, 'b')
    end
  end
end
