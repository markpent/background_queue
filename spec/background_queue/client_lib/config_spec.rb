require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue'

unless defined? Rails
  module Rails; end
end
  
describe "Client Config" do

  context "using map" do
    context "loading server entry" do
      it "creates a server entry if all required string fields exist" do
        entry = BackgroundQueue::ClientLib::Config::Server.new({
            'host'=>"127.0.0.1",
            'port'=>85
        })
        entry.host.should eq("127.0.0.1")
        entry.port.should eq(85)
      end
      
      it "creates a server entry if all required symbol fields exist" do
        entry = BackgroundQueue::ClientLib::Config::Server.new({
            :host=>"127.0.0.1",
            :port=>85
        })
        entry.host.should eq("127.0.0.1")
        entry.port.should eq(85)
      end
      
      it "creates a server entry using default port" do
        entry = BackgroundQueue::ClientLib::Config::Server.new({
            :host=>"127.0.0.1"
        })
        entry.host.should eq("127.0.0.1")
        entry.port.should eq(BackgroundQueue::ClientLib::Config::DEFAULT_PORT)
      end
      
       it "errors if missing or invalid hostname on server entry" do
         expect { 
          BackgroundQueue::ClientLib::Config::Server.new({})
         }.to raise_error(
           BackgroundQueue::LoadError, 
           "Missing 'host' configuration entry"
         )
       end
       
       it "errors if invalid type" do
         expect { 
          BackgroundQueue::ClientLib::Config::Server.new([])
         }.to raise_error(
           BackgroundQueue::LoadError, 
           "Invalid data type (Array), expecting Hash"
         )
       end
    end
    
    context "loading primary server entry" do
      before do
        File.stub(:expand_path) { :expanded_path }
      end
      
      it "creates primary server entry" do
        entry = BackgroundQueue::ClientLib::Config.__prv__build_primary_server_entry({ 'server'=> { :host=>"127.0.0.1" }}, :path_that_exists)
        entry.host.should eq("127.0.0.1")
      end
      
      it "errors if missing" do
        expect { 
          BackgroundQueue::ClientLib::Config.__prv__build_primary_server_entry({}, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Missing 'server' entry in background queue configuration file expanded_path"
        )
      end
      
      it "errors if invalid" do
        expect { 
          BackgroundQueue::ClientLib::Config.__prv__build_primary_server_entry({:server=> {}}, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Error loading 'server' entry from background queue configuration file expanded_path: Missing 'host' configuration entry"
        )
      end
    end
    
    context "loading failover server entries" do
    
      it "creates failover server entries if defined" do
        entries = BackgroundQueue::ClientLib::Config.__prv__build_failover_server_entries({ :failover=> [{ :host=>"127.0.0.1" }, { :host=>"127.0.0.2" }]}, :path_that_exists)
        entries.length.should eq(2)
        entries.first.host.should eq("127.0.0.1")
        entries.last.host.should eq("127.0.0.2")
      end
      
      it "errors if failover entry is invalid" do
        File.stub(:expand_path) { :expanded_path }
        expect { 
          BackgroundQueue::ClientLib::Config.__prv__build_failover_server_entries({ 'failover'=> [{ :host=>"127.0.0.1" }, { }]}, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Error loading 'failover' entry (2) from background queue configuration file expanded_path: Missing 'host' configuration entry"
        )
      end
    
    end
    
    
    
    context "creating Config entry" do
      before do
        File.stub(:expand_path) { :expanded_path }
      end
      
      it "should create Config instance" do
        config = BackgroundQueue::ClientLib::Config.load_hash({
            :server=>{:host=>"127.0.0.1"},
            :failover=>[{:host=>"127.0.0.2"}, {:host=>"127.0.0.3"}],
            :memcache=> "127.0.0.1:4000"
        }, :path_that_exists)
        config.server.host.should eq("127.0.0.1")
        config.failover.length.should eq(2)
        config.failover.first.host.should eq("127.0.0.2")
        config.failover.last.host.should eq("127.0.0.3")
        config.memcache.length.should eq(1)
        config.memcache.first.should eq('127.0.0.1:4000')
      end
      
      it "should fail when missing server" do
        expect { 
          config = BackgroundQueue::ClientLib::Config.load_hash({ }, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Missing 'server' entry in background queue configuration file expanded_path"
        )
      end
      
      it "should fail when missing memcache" do
        expect { 
          config = BackgroundQueue::ClientLib::Config.load_hash({ :server=>{:host=>"127.0.0.1"} }, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Missing 'memcache' entry in configuration file expanded_path"
        )
      end
      
      it "should not fail when missing failover" do
        config = BackgroundQueue::ClientLib::Config.load_hash({
            :server=>{:host=>"127.0.0.1"},
            :memcache=> "127.0.0.1:4000"
        }, :path_that_exists)
        config.failover.length.should eq(0)
      end
    end
  end

end
