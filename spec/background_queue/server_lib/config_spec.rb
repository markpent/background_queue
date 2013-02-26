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
    
    context "loading listen entry" do
      it "defaults to 0.0.0.0:#{BackgroundQueue::Config::DEFAULT_PORT} if missing" do
        entry = BackgroundQueue::ServerLib::Config::Address.new(nil)
        entry.host.should eq("0.0.0.0")
        entry.port.should eq(BackgroundQueue::Config::DEFAULT_PORT)
      end
      
      it "defaults to 0.0.0.0 if host missing" do
        entry = BackgroundQueue::ServerLib::Config::Address.new({:port=>3001})
        entry.host.should eq("0.0.0.0")
        entry.port.should eq(3001)
      end
      
      it "defaults to port #{BackgroundQueue::Config::DEFAULT_PORT}" do
        entry = BackgroundQueue::ServerLib::Config::Address.new({:host=>"127.0.0.1"})
        entry.host.should eq("127.0.0.1")
        entry.port.should eq(BackgroundQueue::Config::DEFAULT_PORT)
      end
      
      it "errors if the host is invalid ap address" do
        expect { BackgroundQueue::ServerLib::Config::Address.new({:host=>"x.y.z"}) }.to raise_exception("Invalid host: x.y.z")
      end
      
      it "errors if the port is an invalid number" do
        expect { BackgroundQueue::ServerLib::Config::Address.new({:port=>"dsfg"}) }.to raise_exception("Invalid port: dsfg")
      end
      
      it "wraps the configuration file path in errors" do
        File.stub(:expand_path) { :expanded_path }
        expect { 
          BackgroundQueue::ServerLib::Config.__prv__get_address_entry({:address=>{:host=>"x.y.z"}}, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Error loading 'address' entry in background queue server configuration file expanded_path: Invalid host: x.y.z"
        )
      end
      
    end
    
    context "#get_connections_per_worker_entry" do
      it "gets the entry" do
        entry = BackgroundQueue::ServerLib::Config.__prv__get_connections_per_worker_entry({:connections_per_worker=>10}, :path_that_exists)
        entry.should eq(10)
      end
      
      it "errors if entry is missing" do
        File.stub(:expand_path) { :expanded_path }
        expect { 
          BackgroundQueue::ServerLib::Config.__prv__get_connections_per_worker_entry({}, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Missing 'connections_per_worker' entry in background queue server configuration file expanded_path"
        )
      end
      
      it "errors if entry is not an Integer" do
        File.stub(:expand_path) { :expanded_path }
        expect { 
          BackgroundQueue::ServerLib::Config.__prv__get_connections_per_worker_entry({:connections_per_worker=>"abc"}, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Error loading 'connections_per_worker' entry in background queue server configuration file expanded_path: invalid data type (String), expecting Integer"
        )
      end
    end
    
    context "#get_system_task_options_entry" do
      it "gets a hash of options" do
        opts = BackgroundQueue::ServerLib::Config.__prv__get_system_task_options_entry({:system_task_options=>{:a=>:b}}, :path_that_exists)
        opts.should eq({:a=>:b})
      end
      
      it "allows no options" do
        opts = BackgroundQueue::ServerLib::Config.__prv__get_system_task_options_entry({}, :path_that_exists)
        opts.should eq({})
      end
      
      it "errors if the jobs entry is not a hash" do
        File.stub(:expand_path) { :expanded_path }
        expect { 
          BackgroundQueue::ServerLib::Config.__prv__get_system_task_options_entry({:system_task_options=>"abc"}, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Error loading 'system_task_options' entry in background queue server configuration file expanded_path: invalid data type (String), expecting Hash (of options)"
        )
      end
      
    end
    
    
    context "#get_jobs_entry" do
      it "gets an array of entries" do
        BackgroundQueue::ServerLib::Config::Job.should_receive(:new).twice.and_return(:job)
        jobs = BackgroundQueue::ServerLib::Config.__prv__get_jobs_entry({:jobs=>[:one, :two]}, :path_that_exists)
        jobs.should eq([:job, :job])
      end
      
      it "allows no jobs" do
        jobs = BackgroundQueue::ServerLib::Config.__prv__get_jobs_entry({}, :path_that_exists)
        jobs.should eq([])
      end
      
      it "errors if the jobs entry is not an array" do
        File.stub(:expand_path) { :expanded_path }
        expect { 
          BackgroundQueue::ServerLib::Config.__prv__get_jobs_entry({:jobs=>"abc"}, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Error loading 'jobs' entry in background queue server configuration file expanded_path: invalid data type (String), expecting Array (of jobs)"
        )
      end
      
      it "passes job loading errors on" do
        File.stub(:expand_path) { :expanded_path }
        BackgroundQueue::ServerLib::Config::Job.should_receive(:new).and_raise("blah")
        expect { 
          BackgroundQueue::ServerLib::Config.__prv__get_jobs_entry({:jobs=>[:a]}, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Error loading 'jobs' entry in background queue server configuration file expanded_path: blah"
        )
      end
    end
    
    context "#Job.initialize" do
      it "will load at" do
        job = BackgroundQueue::ServerLib::Config::Job.new(:at=>"something", :worker=>:abc)
        job.type.should eq(:at)
        job.at.should eq("something")
      end
      
      it "will load in" do
        job = BackgroundQueue::ServerLib::Config::Job.new(:in=>"something", :worker=>:abc)
        job.type.should eq(:in)
        job.in.should eq("something")
      end
      
      it "will load cron" do
        job = BackgroundQueue::ServerLib::Config::Job.new(:cron=>"something", :worker=>:abc)
        job.type.should eq(:cron)
        job.cron.should eq("something")
      end
      
      it "will load the arguments" do
        job = BackgroundQueue::ServerLib::Config::Job.new(:cron=>"something", :worker=>:abc, :args=>{:a=>:b})
        job.args.should eq({:a=>:b})
      end
      
      it "will error if timer not designated" do
        expect { 
          BackgroundQueue::ServerLib::Config::Job.new(:worker=>:abc)
        }.to raise_error(
          "Job is missing timer designation (at, in or cron)"
        )
      end
      
      it "will error if worker not designated" do
        expect { 
          BackgroundQueue::ServerLib::Config::Job.new(:at=>"abc")
        }.to raise_error(
          "Job is missing worker entry"
        )
      end
      
      it "will error if the arguments are not a map" do
        expect { 
          BackgroundQueue::ServerLib::Config::Job.new(:at=>"abc", :worker=>:abc, :args=>[])
        }.to raise_error(
          "Invalid 'args' entry in job: expecting Hash of arguments, got Array"
        )
      end
      
    end
    
    context "#Job.schedule" do
      subject {
        job = BackgroundQueue::ServerLib::Config::Job.new(:at=>"something", :worker=>:abc)
        job.type = nil
        job.at = nil
        job
      }
      before do
        subject.should_receive(:run).with(:server)
      end
      
      let(:scheduler) { double("scheduler") }
      
      it "schedules at a time" do
        subject.type = :at
        subject.at = :time
        scheduler.should_receive(:at).with(:time).and_yield
        subject.schedule(scheduler, :server)
      end
      
      it "schedules in a time" do
        subject.type = :in
        subject.in = :time
        scheduler.should_receive(:in).with(:time).and_yield
        subject.schedule(scheduler, :server)
      end
      
      it "schedules by a cron time" do
        subject.type = :cron
        subject.cron = :time
        scheduler.should_receive(:cron).with(:time).and_yield
        subject.schedule(scheduler, :server)
      end
      
      it "schedules every time" do
        subject.type = :every
        subject.every = :time
        scheduler.should_receive(:every).with(:time).and_yield
        subject.schedule(scheduler, :server)
      end
    end
    
    context "#Job.run" do
      it "adds a task to the queue" do
        job = BackgroundQueue::ServerLib::Config::Job.new(:at=>"something", :worker=>:abc, :args=>{:a=>:b})
        server = SimpleServer.new(:config=>double("config", :system_task_options=>{}), :task_queue=>double("task_queue"))
        server.task_queue.should_receive(:add_task)
        job.run(server)
      end
      
    end
    
    context "#get_task_file_entry" do
      before do
        File.stub(:expand_path) { :expanded_path }
      end
      
      it "creates a task_file entry if the file exists" do
        File.should_receive(:exist?).with('path').and_return(true)
        entry = BackgroundQueue::ServerLib::Config.__prv__get_task_file_entry({:task_file=>'path'}, :path)
        entry.should eq('path')
      end
      
      it "creates a task_file entry if the directory is writable" do
        File.should_receive(:exist?).with('path').and_return(false)
        File.should_receive(:dirname).with('path').and_return('dir')
        File.should_receive(:exist?).with('dir').and_return(true)
        FileUtils.should_receive(:touch).with('path')
        FileUtils.should_receive(:rm).with('path')
        entry = BackgroundQueue::ServerLib::Config.__prv__get_task_file_entry({:task_file=>'path'}, :path)
        entry.should eq('path')
      end
      
      it "creates a task_file entry if the directory can be created" do
        File.should_receive(:exist?).with('path').and_return(false)
        File.should_receive(:dirname).with('path').and_return('dir')
        File.should_receive(:exist?).with('dir').and_return(false)
        FileUtils.should_receive(:mkdir_p).with('dir')
        entry = BackgroundQueue::ServerLib::Config.__prv__get_task_file_entry({:task_file=>'path'}, :path)
        entry.should eq('path')
      end
      
      it "errors if the directory can not be created" do
        File.should_receive(:exist?).with('path').and_return(false)
        File.should_receive(:dirname).with('path').and_return('dir')
        File.should_receive(:exist?).with('dir').and_return(false)
        FileUtils.should_receive(:mkdir_p).with('dir').and_raise("Permission Denied")
        expect { 
          BackgroundQueue::ServerLib::Config.__prv__get_task_file_entry({:task_file=>'path'}, :path)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Error loading 'task_file' entry in background queue server configuration file expanded_path: unable to create directory dir (Permission Denied)"
        )
      end
      
      it "errors if the directory can not be written to" do
        File.should_receive(:exist?).with('path').and_return(false)
        File.should_receive(:dirname).with('path').and_return('dir')
        File.should_receive(:exist?).with('dir').and_return(true)
        FileUtils.should_receive(:touch).with('path').and_raise("Permission Denied")
        expect { 
          BackgroundQueue::ServerLib::Config.__prv__get_task_file_entry({:task_file=>'path'}, :path)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Error loading 'task_file' entry in background queue server configuration file expanded_path: unable to write to file path (Permission Denied)"
        )
      end

      it "errors if invalid type" do
        expect { 
          BackgroundQueue::ServerLib::Config.__prv__get_task_file_entry({:task_file=>123}, :path)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Error loading 'task_file' entry in background queue server configuration file expanded_path: Invalid data type (Fixnum), expecting String"
        )
      end
      
      it "allows if missing or nil" do
        
        BackgroundQueue::ServerLib::Config.__prv__get_task_file_entry({:task_file=>nil}, :path).should eq(nil)
        BackgroundQueue::ServerLib::Config.__prv__get_task_file_entry({}, :path).should eq(nil)
        
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
            :connections_per_worker=>10,
            :jobs=>[{:at=>"some time", :worker=>:something}],
            :error_reporting=>{
              :to=>"test@test.com"
            }
        }, :path_that_exists)
        config.workers.length.should eq(2)
        config.workers.first.uri.port.should eq(801)
        config.workers.last.uri.port.should eq(802)
        config.jobs.length.should eq(1)
        config.jobs.first.at.should eq('some time')
        config.secret.should eq('1234567890123456789012345678901234567890')
        config.error_reporting.enabled.should be_true
        config.error_reporting.to.should eq("test@test.com")
        config.error_reporting.server.should eq("localhost")
        config.error_reporting.port.should eq(25)
        config.error_reporting.helo.should_not be_nil
        config.error_reporting.from.should_not be_nil
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
      
      it "should fail when missing connections_per_worker" do
        expect { 
          config = BackgroundQueue::ServerLib::Config.load_hash({ :workers=>['http://127.0.0.1:802/background_queue'], :secret=>'1234567890123456789012345678901234567890' }, :path_that_exists)
        }.to raise_error(
          BackgroundQueue::LoadError, 
          "Missing 'connections_per_worker' entry in background queue server configuration file expanded_path"
        )
      end
     
    end
  end

end
