require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_worker'

class ThisWorkerExists
  
end

describe BackgroundQueue::Worker::WorkerLoader do

  let(:worker_entry) {
    BackgroundQueue::Worker::WorkerLoader::WorkerEntry.new(:worker, :path, Time.at(10), :worker_name)
  }
    
  context "#worker_class_name" do
    it "will convert to camelcase" do
      subject.worker_class_name("something").should eq("Something")
      subject.worker_class_name("something_else").should eq("SomethingElse")
    end
  end
  
  
  context "#worker_path" do
    it "will get the worker path using the worker name" do
      BackgroundQueue::Worker::Config.worker_path = "ROOT"
      subject.worker_path("something").should eq("ROOT/something.rb")
      subject.worker_path("something_else").should eq("ROOT/something_else.rb")
    end
  end
  
  context "#load_worker" do
    it "will wrap a worker in a worker entry if the file loads and defines the worker class" do
      subject.should_receive(:load_file).with(:path).and_return(true)
      subject.should_receive(:load_class).with(:worker_name, :path).and_return(:clazz)
      subject.should_receive(:worker_path).with(:worker_name).and_return(:path)
      File.should_receive(:mtime).with(:path).and_return(:datestamp)
      worker_entry = subject.load_worker(:worker_name)
      worker_entry.worker.should eq(:clazz)
      worker_entry.name.should eq(:worker_name)
      worker_entry.datestamp.should eq(:datestamp)
      worker_entry.path.should eq(:path)
    end
  end
  
  context "#load_file" do
    it "will load a file if it is a valid ruby file" do
      path = File.expand_path(File.dirname(__FILE__) + '/../../resources/example_worker.rb')
      subject.load_file(path)
    end
    
    it "will raise an error if the file does not exist" do
      path = File.expand_path(File.dirname(__FILE__) + '/../../resources/example_worker_not_found.rb')
      expect { subject.load_file(path) }.to raise_exception
    end
    
    it "will raise an error if the file is not valid ruby" do
      path = File.expand_path(File.dirname(__FILE__) + '/../../resources/example_worker_with_error.rb')
      expect { subject.load_file(path) }.to raise_exception
    end
  end
  
  context "#load_class" do
    it "will create an instance of the worker class" do
      subject.load_class("this_worker_exists", "path").class.name.should eq("ThisWorkerExists")
    end
    
    it "will error if the class is not found" do
      expect { subject.load_class("this_worker_does_not_exist", "path") }.to raise_exception("path did not define ThisWorkerDoesNotExist")
    end
  end
  
  context "#reload_if_updated" do
    it "will reload the worker if the filestamp has changed" do
      File.should_receive(:mtime).with(:path).and_return(Time.at(11))
      subject.should_receive(:load_file).with(:path).and_return(true)
      subject.should_receive(:load_class).with(:worker_name, :path).and_return(:new_worker)
      
      subject.reload_if_updated(worker_entry)
      worker_entry.worker.should eq(:new_worker)
    end
    
    it "will not reload the worker if the filestamp has not changed" do
      File.should_receive(:mtime).with(:path).and_return(Time.at(10))
      subject.reload_if_updated(worker_entry)
      worker_entry.worker.should eq(:worker)
    end
  end
  
  context "#get_worker" do
    it "will load the worker if not in cache" do
      subject.should_receive(:load_worker).with(:worker_name).and_return(worker_entry)
      subject.get_worker(:worker_name).should eq(:worker)
    end
    
    it "will cache the results" do
      subject.should_receive(:load_worker).with(:worker_name).and_return(worker_entry)
      subject.should_receive(:reload_if_updated).with(worker_entry).and_return(nil)
      subject.get_worker(:worker_name).should eq(:worker)
      subject.get_worker(:worker_name).should eq(:worker)
    end
  end
  

end
