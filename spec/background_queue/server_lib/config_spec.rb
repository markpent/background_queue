require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'

unless defined? Rails
  module Rails; end
end
  
describe "Server Config" do

  context "using map" do
    context "loading worker entry" do
      it "creates a worker entry if all required string fields exist" do
        entry = BackgroundQueue::ServerLib::Config::Worker.new('http://127.0.0.1:801/background_queue')
        entry.url.should eq('http://127.0.0.1:801/background_queue')
        entry.uri.port.should eq(801)
      end

      it "errors if invalid type" do
        expect { 
          BackgroundQueue::ServerLib::Config::Worker.new([])
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Invalid data type (Array), expecting String (as a url)"
        )
      end
      
      it "errors if missing or nil" do
        expect { 
          BackgroundQueue::ServerLib::Config::Worker.new(nil)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Missing worker url"
        )
      end
      
      it "errors if invalid url" do
        expect { 
          BackgroundQueue::ServerLib::Config::Worker.new("something:/\\asdf dsafdsfdsaf")
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Invalid worker url (something:/\\asdf dsafdsfdsaf)"
        )
      end
    end
    
    context "loading worker entries" do
      it "creates an array of workers" do
        entries = BackgroundQueue::ServerLib::Config.__prv__build_worker_entries({:workers=>['http://127.0.0.1:801/background_queue', 'http://127.0.0.1:802/background_queue', 'http://127.0.0.1:803/background_queue']}, :path_that_exists)
        entries.length.should eq(3)
        entries.first.uri.port.should eq(801)
        entries.last.uri.port.should eq(803)
      end
      
      it "errors if failover entry is invalid" do
        File.stub(:expand_path) { :expanded_path }
        expect { 
          BackgroundQueue::ServerLib::Config.__prv__build_worker_entries({ 'workers'=> ['http://127.0.0.1:801/background_queue','']}, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Error loading 'worker' entry (2) from background queue server configuration file expanded_path: Missing worker url"
        )
      end
    end
    
    context "loading secret entry" do
      it "creates an array of workers" do
        secret = BackgroundQueue::ServerLib::Config.__prv__get_secret_entry({:secret=>'1234567890123456789012345678901234567890'}, :path_that_exists)
        secret.should eq('1234567890123456789012345678901234567890')
      end
      
      it "errors if secret is missing" do
        File.stub(:expand_path) { :expanded_path }
        expect { 
          BackgroundQueue::ServerLib::Config.__prv__get_secret_entry({}, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Missing 'secret' entry in background queue server configuration file expanded_path"
        )
      end
      
      it "errors if secret is too short" do
        File.stub(:expand_path) { :expanded_path }
        expect { 
          BackgroundQueue::ServerLib::Config.__prv__get_secret_entry({:secret=>'1234567890123456789'}, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Error loading 'secret' entry in background queue server configuration file expanded_path: length too short (must be at least 20 characters long)"
        )
      end
    end
    

    context "creating Config entry" do
      before do
        File.stub(:expand_path) { :expanded_path }
      end
      
      it "should create Config instance" do
        config = BackgroundQueue::ServerLib::Config.load_hash({
            :workers=>['http://127.0.0.1:801/background_queue', 'http://127.0.0.1:802/background_queue'],
            :secret=>'1234567890123456789012345678901234567890',
            :memcache=> "127.0.0.1:4000"
        }, :path_that_exists)
        config.workers.length.should eq(2)
        config.workers.first.uri.port.should eq(801)
        config.workers.last.uri.port.should eq(802)
        config.memcache.length.should eq(1)
        config.memcache.first.should eq('127.0.0.1:4000')
        config.secret.should eq('1234567890123456789012345678901234567890')
      end
      
      it "should fail when missing workers" do
        expect { 
          config = BackgroundQueue::ServerLib::Config.load_hash({ }, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Missing 'workers' in background queue server configuration file expanded_path"
        )
      end
      
      it "should fail when missing secret" do
        expect { 
          config = BackgroundQueue::ServerLib::Config.load_hash({ :workers=>['http://127.0.0.1:802/background_queue'] }, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Missing 'secret' entry in background queue server configuration file expanded_path"
        )
      end
      
      it "should fail when missing memcache" do
        expect { 
          config = BackgroundQueue::ServerLib::Config.load_hash({ :workers=>['http://127.0.0.1:802/background_queue'], :secret=>'1234567890123456789012345678901234567890' }, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Missing 'memcache' entry in configuration file expanded_path"
        )
      end
      
     
    end
  end

end
