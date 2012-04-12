require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


class SimpleItem
  attr_accessor :id
  attr_accessor :priority
  
  def initialize(id, priority)
    @id = id
    @priority = priority
  end
end


describe "Priority Queue" do

  context "internal array of queues" do
    
    subject { BackgroundQueue::ServerLib::PriorityQueue.new }
    
    it "can insert queue entries" do
      
      q1 = subject.__prv__insert_queue_at_index(1, 0)
      q3 = subject.__prv__insert_queue_at_index(3, 1)
      q2 = subject.__prv__insert_queue_at_index(2, 1)
      
      subject.__prv__get_queues.should eq([q1, q2, q3])
      
    end
    
    
    it "can add a queue to the correct priority index" do
      q3 = subject.__prv__get_queue_for_priority(3)
      
      subject.__prv__get_queues.should eq([q3])
      
      q2 = subject.__prv__get_queue_for_priority(2)
      subject.__prv__get_queues.should eq([q2, q3])
      
      q5 = subject.__prv__get_queue_for_priority(5)
      subject.__prv__get_queues.should eq([q2, q3, q5])
      
      q4 = subject.__prv__get_queue_for_priority(4)
      subject.__prv__get_queues.should eq([q2, q3, q4, q5])
    end
    
    it "can get the next priority entry" do
      subject.__prv__get_queue_for_priority(3)
      q2 = subject.__prv__get_queue_for_priority(2)
      subject.__prv__get_queue_for_priority(4)
      
      subject.__prv__get_next_queue.should eq(q2)
    end
    
    it "can remove the queue entry" do
      
      q3 = subject.__prv__get_queue_for_priority(3)
      q2 = subject.__prv__get_queue_for_priority(2)
      q5 = subject.__prv__get_queue_for_priority(5)
      q4 = subject.__prv__get_queue_for_priority(4)
      
      subject.__prv__get_queues.should eq([q2, q3, q4, q5])
      
      subject.__prv__remove_queue(q3)
      subject.__prv__get_queues.should eq([q2, q4, q5])
      
      subject.__prv__remove_queue(q2)
      subject.__prv__get_queues.should eq([q4, q5])
      
      subject.__prv__remove_queue(q5)
      subject.__prv__get_queues.should eq([q4])
      
      
      subject.__prv__remove_queue(q4)
      subject.__prv__get_queues.should eq([])
    end
    
    
  end
  
  context "single priority" do
    
    subject { BackgroundQueue::ServerLib::PriorityQueue.new }
    
    it "adds a single entry" do
      subject.push(SimpleItem.new(2, 1))
      subject.__prv__get_queues.length.should eq(1)
      subject.__prv__get_queues.first.priority.should eq(1)
      subject.__prv__get_queues.first.first.id.should eq(2)
      
    end
    
    it "returns a single entry" do
      subject.push(SimpleItem.new(2, 1))
      popped = subject.pop
      popped.id.should eq(2)
      subject.__prv__get_queues.length.should eq(0)
    end
    
    it "returns nil if empty" do
      subject.pop.should eq(nil)
    end
    
    it "returns entries in same order added" do
      subject.push(SimpleItem.new(2, 1))
      subject.push(SimpleItem.new(3, 1))
      subject.pop.id.should eq(2)
      subject.pop.id.should eq(3)
      subject.__prv__get_queues.length.should eq(0)
    end

  end
  
  context "multiple priorities" do
    subject { BackgroundQueue::ServerLib::PriorityQueue.new }
    
    it "can add multiple entries" do
      subject.push(SimpleItem.new(2, 2))
      subject.push(SimpleItem.new(3, 1))
      subject.__prv__get_queues.length.should eq(2)
      subject.__prv__get_queues.first.priority.should eq(1)
      subject.__prv__get_queues.last.priority.should eq(2)
    end
    
    it "returns entries in correct priority" do
      subject.push(SimpleItem.new(2, 2))
      subject.push(SimpleItem.new(3, 1))
      
      subject.pop.id.should eq(3)
      subject.pop.id.should eq(2)
      subject.__prv__get_queues.length.should eq(0)
    end
    
    it "returns entries in correct priority and added order" do
      subject.push(SimpleItem.new(2, 2))
      subject.push(SimpleItem.new(3, 3))
      subject.push(SimpleItem.new(4, 2))
      
      subject.pop.id.should eq(2)
      subject.pop.id.should eq(4)
      subject.pop.id.should eq(3)
      subject.__prv__get_queues.length.should eq(0)
    end
    
    it "knows the highest priority" do
      subject.push(SimpleItem.new(2, 2))
      subject.priority.should eq(2)
      subject.push(SimpleItem.new(3, 3))
      subject.priority.should eq(2)
      subject.pop.id.should eq(2)
      subject.priority.should eq(3)
      subject.pop.id.should eq(3)
      subject.priority.should eq(nil)
    end
    
    it "can remove existing item" do
      subject.push(SimpleItem.new(2, 2))
      subject.push(SimpleItem.new(3, 3))
      subject.remove(SimpleItem.new(2, 2))
      subject.__prv__get_queues.length.should eq(1)
      subject.__prv__get_queues.first.priority.should eq(3)
    end
      
  end
end
