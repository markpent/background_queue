require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_worker'


describe BackgroundQueue::Worker::Environment do

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
      :auth=>"ABCD",
      :task=>{:params=>{:a=>"b"}, :owner_id=>'oid', :job_id=>'jid', :id=>'tid', :priority=>1}.to_json,
      :server_port=>213
    }
  }
  
  let(:response) {
    double("resp")
  }
  
  let(:request) {
    double("req", :remote_ip=>"192.168.1.1")
  }
  
  let(:controller) {
    double("controller", :logger=>logger, :response=>response, :params=>params, :request=>request)
  }
  
  
  context "#init_params" do
    it "will load task data from params" do
      subject.init_params(params)
      subject.params[:a].should eq("b")
      subject.owner_id.should eq("oid")
      subject.job_id.should eq("jid")
      subject.task_id.should eq("tid")
      subject.priority.should eq(1)
    end
    
    it "will error if the task definition is not valid json" do
      params[:task] = '[123'
      expect { subject.init_params(params) }.to raise_exception
    end
    
    it "will error if the task definition is not a json hash" do
      params[:task] = '[123]'
      expect { subject.init_params(params) }.to raise_exception("Invalid json root object (should be hash)")
    end
  end
  
  context "#init_server_address" do
    it "will get the server ip from the request" do
      subject.init_server_address(controller)
      subject.server_address.port.should eq(213)
      subject.server_address.host.should eq("192.168.1.1")
    end
  end
  
  
end
