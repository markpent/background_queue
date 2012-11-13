require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_worker'

class DummyClass
  include BackgroundQueue::Worker::Calling
end

describe "Calling" do

  let(:logger) {
    l = double("logger")
    l.stub(:debug)
    l.stub(:info)
    l.stub(:error)
    l.stub(:warn)
    l
  }
  
  let(:params) {
    {
      :auth=>"ABCD"
    }
  }
  
  let(:response) {
    double("resp")
  }
  
  let(:headers) { {} }
  
  
  let(:subject) {
    s = DummyClass.new
    s.stub(:params).and_return(params)
    s.stub(:logger).and_return(logger)
    s.stub(:response).and_return(response)
    s.stub(:headers).and_return(headers)
    s
  }
  
  before do
    BackgroundQueue::Worker::Config.secret = "ABCD"
  end
  
  context "#check_secret" do
    it "will pass if the secret matches" do
      subject.check_secret.should be_true
    end
    
    it "will fail and return a 401 auth error if secret does not match" do
      BackgroundQueue::Worker::Config.secret = "XYZ"
      subject.should_receive(:render).with(:text=>"Invalid auth (ABCD)", :status=>401)
      subject.check_secret.should be_false
    end
  end
  
  context "#init_environment" do
    it "will instanciate an environment and init it" do
      BackgroundQueue::Worker::Environment.any_instance.should_receive(:init_from_controller).with(subject)
      subject.init_environment
    end
  end
  
  context "#run_worker" do
    it "should return if check_secret fails" do
      subject.should_receive(:check_secret).and_return(false)
      subject.run_worker()
    end
    
    it "will call worker if all is ok" do
      env = double("env", :worker=>:worker_name)
      worker = double("worker")
      worker.should_receive(:set_environment).with(env)
      
      subject.should_receive(:call_worker).with(worker, env)
      subject.should_receive(:init_environment).and_return(env)
      BackgroundQueue::Worker::WorkerLoader.should_receive(:get_worker).with(:worker_name).and_return(worker)
      subject.run_worker
    end
    
    it "will render the error and raise it if worker does not initialize correctly" do
      subject.should_receive(:init_environment).and_raise "ERROR"
      subject.should_receive(:render).with(:text=>"Error initializing worker: ERROR", :status=>500)
      expect { subject.run_worker }.to raise_exception("ERROR")
    end
  end
  
  context "#call_worker" do
    it "will call worker.run within a render block" do
      env = double("env", :step=>nil)
      worker = double("worker")
      worker.should_receive(:set_environment).with(nil)
      subject.should_receive(:set_process_name).with(env)
      subject.should_receive(:revert_process_name)
      env.should_receive(:set_output).with(:output)
      worker.should_receive(:run)
      subject.should_receive(:render) { |opts|
        opts[:text].call(:response, :output)
      }
      subject.call_worker(worker, env)
      subject.headers['X-Accel-Buffering'].should eq('no')
    end
  end

end
