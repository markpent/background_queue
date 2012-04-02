require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
  
describe "Utils" do

  context "hash" do
    it "gets an entry by string" do
      BackgroundQueue::Utils.get_hash_entry({:key=>:value}, "key").should eq(:value)
      BackgroundQueue::Utils.get_hash_entry({'key'=>:value}, "key").should eq(:value)
    end
    
    it "gets an entry by symbol" do
      BackgroundQueue::Utils.get_hash_entry({:key=>:value}, :key).should eq(:value)
      BackgroundQueue::Utils.get_hash_entry({'key'=>:value}, :key).should eq(:value)
    end
  end
  
  context "any key hash" do
    it "wraps hash with any key accessor" do
      hash = {:a=>:b}
      any_hash = BackgroundQueue::Utils::AnyKeyHash.new(hash)
      any_hash[:a].should eq(:b)
      any_hash["a"].should eq(:b)
    end
  end

end
