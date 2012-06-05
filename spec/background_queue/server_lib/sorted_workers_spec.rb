require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


class BasicWorker
  attr_accessor :connections
  def initialize(connections)
    @connections = connections
  end
end

describe BackgroundQueue::ServerLib::SortedWorkers do

  
  
  context "#add_worker" do
    it "adds the worker to the correct position in list" do
      w1 = BasicWorker.new(1)
      w2 = BasicWorker.new(2)
      w3 = BasicWorker.new(3)
      w4 = BasicWorker.new(0)
      subject.add_worker(w1)
      subject.add_worker(w2)
      subject.add_worker(w3)
      subject.add_worker(w4)
      subject.worker_list.should eq([w4, w1, w2, w3])
    end
  end
  
  context "#remove_worker" do
    it "just removed the worker from the array" do
      w1 = double("worker")
      subject.add_worker(w1)
      subject.worker_list[0].should be(w1)
      subject.remove_worker(w1)
      subject.worker_list.should have(0).items
    end
  end
  
  context "#adjust_worker" do
    it "moves the worker forward if it now has less connections to the worker before it" do
      w1 = BasicWorker.new(1)
      w2 = BasicWorker.new(1)
      
      subject.add_worker(w1)
      subject.add_worker(w2)
      w2.connections = 0
      
      subject.adjust_worker(w2)
      subject.worker_list.should eq([w2, w1])
    end
    
    it "moves the worker back if it now has more connections to the worker after it" do
      w1 = BasicWorker.new(1)
      w2 = BasicWorker.new(2)
      
      subject.add_worker(w1)
      subject.add_worker(w2)
      
      w1.connections = 3
      subject.adjust_worker(w1)
      subject.worker_list.should eq([w2, w1])
    end
    
    it "leaves the worker where it is if its positions hasnt changed" do
      w1 = BasicWorker.new(1)
      w2 = BasicWorker.new(2)
      w3 = BasicWorker.new(3)
      
      subject.add_worker(w1)
      subject.add_worker(w2)
      subject.add_worker(w3)
      subject.worker_list.should eq([w1,w2,w3])
      
      subject.adjust_worker(w2)
      subject.worker_list.should eq([w1,w2,w3])
      
    end
    
    it "leaves where where it is if connection counts are the same" do
      w1 = BasicWorker.new(1)
      w2 = BasicWorker.new(2)
      w3 = BasicWorker.new(3)
      w4 = BasicWorker.new(4)
      
      subject.add_worker(w1)
      subject.add_worker(w2)
      subject.add_worker(w3)
      subject.add_worker(w4)
      subject.worker_list.should eq([w1,w2,w3,w4])
      
      w2.connections = 3
      subject.adjust_worker(w2)
      subject.worker_list.should eq([w1,w2,w3,w4])
      w2.connections = 1
      subject.adjust_worker(w2)
      subject.worker_list.should eq([w1,w2,w3,w4])
    end
    
    it "can jump multiple places" do
      w1 = BasicWorker.new(1)
      w2 = BasicWorker.new(2)
      w3 = BasicWorker.new(2)
      w4 = BasicWorker.new(2)
      
      subject.add_worker(w1)
      subject.add_worker(w2)
      subject.add_worker(w3)
      subject.add_worker(w4)
      subject.worker_list.should eq([w1,w4,w3,w2])
      
      w2.connections = 3
      subject.adjust_worker(w2)
      subject.worker_list.should eq([w1,w4,w3,w2])
      w3.connections = 1
      subject.adjust_worker(w3)
      subject.worker_list.should eq([w1,w3,w4,w2])
    end
  end
  
  
end
