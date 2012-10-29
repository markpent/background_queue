require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'background_queue'

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
  
  
   context "#current_environment" do
      it "gets_the_current environment from env" do
        ENV.should_receive(:has_key?).with("RAILS_ENV") { true }
        ENV.should_receive(:[]).with("RAILS_ENV") { :the_env }
        BackgroundQueue::Utils.current_environment.should eq(:the_env)
      end
      
      it "gets_the_current environment from Rails" do
        ENV.should_receive(:has_key?).with("RAILS_ENV") { false }
        Rails.should_receive(:env) { :the_env }
        BackgroundQueue::Utils.current_environment.should eq(:the_env)
      end
      
      context "with development environment" do
        before do
          BackgroundQueue::Config.stub(:current_environment) { 'development' }
        end
        
        it "extracts the correct environment entry from the hash" do
          BackgroundQueue::Config.__prv__extract_enviroment_entry({:development=>:test}, :path_that_exists).should eq(:test)
        end
        
        it "errors if the YAML does not define environment entry" do
          File.stub(:expand_path) { :expanded_path }
          expect { BackgroundQueue::Config.__prv__extract_enviroment_entry({:test=>:test}, :path_that_exists).should eq(:test)}.to raise_error(BackgroundQueue::LoadError, "Error loading YAML for background_queue configuration file at 'expanded_path': missing enviroment root entry: development")
        end
      end
    end

end
