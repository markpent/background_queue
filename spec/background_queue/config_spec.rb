require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

unless defined? Rails
  module Rails; end
end
  
describe "Config" do
 
  context "utility" do
    it "gets an entry by string" do
      BackgroundQueue::Config.get_hash_entry({:key=>:value}, "key").should eq(:value)
      BackgroundQueue::Config.get_hash_entry({'key'=>:value}, "key").should eq(:value)
    end
    
    it "gets an entry by symbol" do
      BackgroundQueue::Config.get_hash_entry({:key=>:value}, :key).should eq(:value)
      BackgroundQueue::Config.get_hash_entry({'key'=>:value}, :key).should eq(:value)
    end
  end
  
  context "loading" do
    context "from file" do
      it "gets an io from a file that exists" do
        File.should_receive(:open).with(:path_that_exists) { :string }
        File.should_receive(:exist?).with(:path_that_exists) { true }
        BackgroundQueue::Config.get_string_from_file(:path_that_exists).should eq(:string)
      end
      
      it "calls load using string if file exists" do
        File.should_receive(:open).with(:path_that_exists) { :string }
        File.should_receive(:exist?).with(:path_that_exists) { true }
        BackgroundQueue::Config.should_receive(:load_string).with(:string, :path_that_exists) { true }
        BackgroundQueue::Config.load_file(:path_that_exists).should eq(true)
      end
      
      it "errors if the file is not found" do
        File.should_receive(:exist?).with(:path_that_does_not_exist) { false }
        File.should_receive(:expand_path).with(:path_that_does_not_exist) { :expanded_path }
        expect { BackgroundQueue::Config.get_string_from_file(:path_that_does_not_exist) }.to raise_error(BackgroundQueue::LoadError, "Failed to open background_queue configuration file at 'expanded_path'")
      end
    end
    
    context "using string" do
      it "executes ERB on the string" do
        BackgroundQueue::Config.evaluate_erb("TEST <%=1+1%>", :path_that_exists).should eq("TEST 2")
      end
      
      it "errors if invalid ERB" do
        File.should_receive(:expand_path).with(:path_that_exists) { :expanded_path }
        expect { BackgroundQueue::Config.evaluate_erb("TEST <%= aa %>", :path_that_exists)}.to raise_error(BackgroundQueue::LoadError, /Error executing ERB for background_queue configuration file at 'expanded_path':/)
      end
      
      it "calls load yaml if erb evaluates" do
        BackgroundQueue::Config.should_receive(:evaluate_erb).with(:string, :path_that_exists) { :loaded_string }
        BackgroundQueue::Config.should_receive(:load_yaml).with(:loaded_string, :path_that_exists) { true }
        BackgroundQueue::Config.load_string(:string, :path_that_exists).should eq(true)
      end
      
      context "loading as YAML" do
        it "gets a hash object if the string is valid YAML" do
          File.stub(:expand_path) { :expanded_path }
          BackgroundQueue::Config.convert_yaml_to_hash("a: b", :path_that_exists).should eq( {'a' => 'b'})
        end
         
        it "errors if the YAML is not a hash" do
          File.stub(:expand_path) { :expanded_path }
          expect { BackgroundQueue::Config.convert_yaml_to_hash("a", :path_that_exists)}.to raise_error(BackgroundQueue::LoadError, "Error loading YAML for background_queue configuration file at 'expanded_path': Root of config should be a hash of environment configurations")
        end
      end
      
      context "extracting the environment entry" do
        it "gets_the_current environment from env" do
          ENV.should_receive(:has_key?).with("RAILS_ENV") { true }
          ENV.should_receive(:[]).with("RAILS_ENV") { :the_env }
          BackgroundQueue::Config.current_environment.should eq(:the_env)
        end
        
        it "gets_the_current environment from Rails" do
          ENV.should_receive(:has_key?).with("RAILS_ENV") { false }
          Rails.should_receive(:env) { :the_env }
          BackgroundQueue::Config.current_environment.should eq(:the_env)
        end
        
        context "with development environment" do
          before do
            BackgroundQueue::Config.stub(:current_environment) { 'development' }
          end
          
          it "extracts the correct environment entry from the hash" do
            BackgroundQueue::Config.extract_enviroment_entry({:development=>:test}, :path_that_exists).should eq(:test)
          end
          
          it "errors if the YAML does not define environment entry" do
            File.stub(:expand_path) { :expanded_path }
            expect { BackgroundQueue::Config.extract_enviroment_entry({:test=>:test}, :path_that_exists).should eq(:test)}.to raise_error(BackgroundQueue::LoadError, "Error loading YAML for background_queue configuration file at 'expanded_path': missing enviroment root entry: development")
          end
        end
      end
      
      context "with extracted environment entry" do
        before do
          BackgroundQueue::Config.stub(:current_environment) { 'development' }
        end
        it "calls load using map" do
          BackgroundQueue::Config.should_receive(:load_hash).with({'a'=>'b'}, :path_that_exists) { true }
          BackgroundQueue::Config.load_yaml("development: { a: b }", :path_that_exists).should eq(true)
        end
      end
    end
    
    context "using map" do
      context "loading server entry" do
        it "creates a server entry if all required string fields exist" do
          entry = BackgroundQueue::Config::Server.new({
              'host'=>"127.0.0.1",
              'port'=>85
          })
          entry.host.should eq("127.0.0.1")
          entry.port.should eq(85)
        end
        
        it "creates a server entry if all required symbol fields exist" do
          entry = BackgroundQueue::Config::Server.new({
              :host=>"127.0.0.1",
              :port=>85
          })
          entry.host.should eq("127.0.0.1")
          entry.port.should eq(85)
        end
        
        it "creates a server entry using default port" do
          entry = BackgroundQueue::Config::Server.new({
              :host=>"127.0.0.1"
          })
          entry.host.should eq("127.0.0.1")
          entry.port.should eq(BackgroundQueue::Config::DEFAULT_PORT)
        end
        
         it "errors if missing or invalid hostname on server entry" do
           expect { 
            BackgroundQueue::Config::Server.new({})
           }.to raise_error(
             BackgroundQueue::LoadError, 
             "Missing 'host' configuration entry"
           )
         end
         
         it "errors if invalid type" do
           expect { 
            BackgroundQueue::Config::Server.new([])
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
          entry = BackgroundQueue::Config.build_primary_server_entry({ 'server'=> { :host=>"127.0.0.1" }}, :path_that_exists)
          entry.host.should eq("127.0.0.1")
        end
        
        it "errors if missing" do
          expect { 
            BackgroundQueue::Config.build_primary_server_entry({}, :path_that_exists)
          }.to raise_error(
            BackgroundQueue::LoadError, 
            "Missing 'server' entry in background queue configuration file expanded_path"
          )
        end
        
        it "errors if invalid" do
          expect { 
            BackgroundQueue::Config.build_primary_server_entry({:server=> {}}, :path_that_exists)
          }.to raise_error(
            BackgroundQueue::LoadError, 
            "Error loading 'server' entry from background queue configuration file expanded_path: Missing 'host' configuration entry"
          )
        end
      end
      
      context "loading failover server entries" do
      
        it "creates failover server entries if defined" do
          entries = BackgroundQueue::Config.build_failover_server_entries({ :failover=> [{ :host=>"127.0.0.1" }, { :host=>"127.0.0.2" }]}, :path_that_exists)
          entries.length.should eq(2)
          entries.first.host.should eq("127.0.0.1")
          entries.last.host.should eq("127.0.0.2")
        end
        
        it "errors if failover entry is invalid" do
          File.stub(:expand_path) { :expanded_path }
          expect { 
            BackgroundQueue::Config.build_failover_server_entries({ 'failover'=> [{ :host=>"127.0.0.1" }, { }]}, :path_that_exists)
          }.to raise_error(
            BackgroundQueue::LoadError, 
            "Error loading 'failover' entry (2) from background queue configuration file expanded_path: Missing 'host' configuration entry"
          )
        end
      
      end
      
      context "loading memcache server" do
        it "loads server from comma separated list" do
          entries = BackgroundQueue::Config.build_memcache_array({ :memcache=> "127.0.0.1:4000 , 127.0.0.1:4001,127.0.0.1:4002"}, :path_that_exists)
          entries.length.should eq(3)
          entries[0].should eq('127.0.0.1:4000')
          entries[1].should eq('127.0.0.1:4001')
          entries[2].should eq('127.0.0.1:4002')
        end
      
        it "errors if missing memcache entry" do
          File.stub(:expand_path) { :expanded_path }
          expect { 
            entries = BackgroundQueue::Config.build_memcache_array({}, :path_that_exists)
          }.to raise_error(
            BackgroundQueue::LoadError, 
            "Missing 'memcache' entry in configuration file expanded_path"
          )
        end
        
        it "errors if memcache entry not String" do
          File.stub(:expand_path) { :expanded_path }
          expect { 
            entries = BackgroundQueue::Config.build_memcache_array({:memcache=>1}, :path_that_exists)
          }.to raise_error(
            BackgroundQueue::LoadError, 
            "Error loading 'memcache' entry in configuration file expanded_path: invalid data type (Fixnum), expecting String (comma separated)"
          )
        end
      end
      
      context "creating Config entry" do
        before do
          File.stub(:expand_path) { :expanded_path }
        end
        
        it "should create Config instance" do
          config = BackgroundQueue::Config.load_hash({
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
            config = BackgroundQueue::Config.load_hash({ }, :path_that_exists)
          }.to raise_error(
            BackgroundQueue::LoadError, 
            "Missing 'server' entry in background queue configuration file expanded_path"
          )
        end
        
        it "should fail when missing memcache" do
          expect { 
            config = BackgroundQueue::Config.load_hash({ :server=>{:host=>"127.0.0.1"} }, :path_that_exists)
          }.to raise_error(
            BackgroundQueue::LoadError, 
            "Missing 'memcache' entry in configuration file expanded_path"
          )
        end
        
        it "should not fail when missing failover" do
          config = BackgroundQueue::Config.load_hash({
              :server=>{:host=>"127.0.0.1"},
              :memcache=> "127.0.0.1:4000"
          }, :path_that_exists)
          config.failover.length.should eq(0)
        end
      end
    end
    
  end
  
  
end
