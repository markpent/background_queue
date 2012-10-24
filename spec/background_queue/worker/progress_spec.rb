require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_worker'


describe BackgroundQueue::Worker::Progress do
  
  let(:callback_object) {
    double("callback_object")
  }
  
  subject { BackgroundQueue::Worker::Progress.new(callback_object) }
  
  context "#start" do
    it "will start at zero with the caption" do
      callback_object.should_receive(:set_progress).with("test", 0.0, subject)
      subject.start("test")
    end
    
    it "will start at zero with no caption" do
      callback_object.should_receive(:set_progress).with("", 0.0, subject)
      subject.start("")
    end
  end
  
  context "#set_main_caption" do
    it "will update the main caption" do
      callback_object.should_receive(:set_progress).with("test", 0.0, subject)
      callback_object.should_receive(:set_progress).with("test2", 0.0, subject)
      subject.start("test")
      subject.set_main_caption("test2")
    end
  end
  
  context "#finish" do
    it "will set the progress to 100% and reset the caption" do
      callback_object.should_receive(:set_progress).with("test", 100.0, subject)
      subject.finish("test")
    end
  end
  
  context "#register_task" do
    it "will store the weight against the key" do
      subject.register_task(:key, 10)
      subject.registered_tasks[:key].should eq(10)
    end
  end
  
  context "#get_task_size" do
    it "will get the size of the task" do
      subject.register_task(:key, 10)
      subject.register_task(:key2, 10)
      subject.get_task_size(:key).should eq(50)
    end
    
  end
  
  context "#start_task" do
    it "will finish any existing task" do
      callback_object.stub(:set_progress)
      subject.register_task(:key, 10)
      subject.register_task(:key2, 10)
      subject.start("main")
      subject.start_task(:key,"sub")
      subject.get_percent.should eq(0)
      subject.get_caption.should eq("main: sub")
      subject.start_task(:key2, "sub2")
      subject.get_percent.should eq(50)
      subject.get_caption.should eq("main: sub2")
    end
  end
  
  context "#set_task_steps" do
    it "will calculate the step size" do
      callback_object.stub(:set_progress)
      subject.register_task(:key, 10)
      subject.start_task(:key,"sub")
      subject.set_task_steps(50)
      subject.inc
      subject.get_percent.should eq(2)
    end
  end
end
