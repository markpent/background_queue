require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

unless defined? Rails
  module Rails; end
end
  
describe "Config" do
 
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
      xit "creates a server entry if all required fields exist" do
        
      end
      
      xit "creates backup server entries if defined" do
        
      end
      
      xit "errors if missing or invalid hostname on server entry" do
        
      end
      
      xit "errors if missing memcache entry" do
        
      end
    end
  end
  
  
end
