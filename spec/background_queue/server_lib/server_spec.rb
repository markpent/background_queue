require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_server'


describe BackgroundQueue::ServerLib::Server do
  
  context "#process_args" do
    it "knows the start command" do
      options = subject.process_args(["start", "-c", "the_path"])
      options[:command].should eq(:start)
    end
    
    it "knows short version of config file path" do
      options = subject.process_args(["start", "-c", "the_path"])
      options[:config].should eq("the_path")
    end
    
    it "knows long version of config file path" do
      options = subject.process_args(["start", "--config", "the_path"])
      options[:config].should eq("the_path")
    end
    
    it "raises an error if no config file is specified when starting" do
      expect { subject.process_args(["start"]) }.to raise_exception
    end

    
    it "knows the stop command" do
      options = subject.process_args(["stop"])
      options[:command].should eq(:stop)
    end
    
    it "knows the test command" do
      options = subject.process_args(["test", "-c", "the_path"])
      options[:command].should eq(:test)
    end
    
    it "raises an error if no config file is specified when testing" do
      expect { subject.process_args(["test"]) }.to raise_exception
    end
    
    it "raises an error if the command is not recognised" do
      expect { subject.process_args(["blah"]) }.to raise_exception
    end
    
    it "knows the short logging path flag" do
      options = subject.process_args(["stop", "-l", "the_path"])
      options[:log_file].should eq("the_path")
    end
    
    it "knows the long logging path flag" do
      options = subject.process_args(["stop", "--logfile", "the_path"])
      options[:log_file].should eq("the_path")
    end
    
    it "knows the short logging level flag" do
      options = subject.process_args(["stop", "-v", "debug"])
      options[:log_level].should eq("debug")
    end
    
    it "knows the long logging level flag" do
      options = subject.process_args(["stop", "--loglevel", "debug"])
      options[:log_level].should eq("debug")
    end
    
    it "knows the short pid path flag" do
      options = subject.process_args(["stop", "-p", "the_path"])
      options[:pid_file].should eq("the_path")
    end
    
    it "knows the long pid path flag" do
      options = subject.process_args(["stop", "--pidfile", "the_path"])
      options[:pid_file].should eq("the_path")
    end
  end

  context "#load_configuration" do
    it "will continue if successful" do
      BackgroundQueue::Config.should_receive(:load_file).with(:path).and_return(true)
      subject.load_configuration(:path).should be_true
    end
    
    it "will raise an error if configuration does not load" do
      BackgroundQueue::Config.should_receive(:load_file).with(:path).and_raise("nooo!")
      expect { subject.load_configuration(:path) }.to raise_exception("nooo!")
    end
  end
  
  context "#resolve_logging_path" do
    it "will handle an absolute path" do
      subject.resolve_logging_path("/path").should eq("/path")
    end
    
    it "will use current working directory when given a relative path" do
      Dir.chdir("/tmp")
      subject.resolve_logging_path("path").should eq("/tmp/path")
    end
  end
  
  context "#set_logging_level" do
    it "will set level debug" do
      log = Logger.new(STDOUT)
      subject.set_logging_level(log, "debug")
      log.level.should eq(Logger::DEBUG)
      subject.set_logging_level(log, "DEBUG")
      log.level.should eq(Logger::DEBUG)
    end
    
    it "will set level info" do
      log = Logger.new(STDOUT)
      subject.set_logging_level(log, "info")
      log.level.should eq(Logger::INFO)
    end
    
    it "will set level warning" do
      log = Logger.new(STDOUT)
      subject.set_logging_level(log, "warn")
      log.level.should eq(Logger::WARN)
    end
    
    it "will set level error" do
      log = Logger.new(STDOUT)
      subject.set_logging_level(log, "error")
      log.level.should eq(Logger::ERROR)
    end
    
    it "will set level fatal" do
      log = Logger.new(STDOUT)
      subject.set_logging_level(log, "fatal")
      log.level.should eq(Logger::FATAL)
    end
    
    it "will default to warning" do
      log = Logger.new(STDOUT)
      subject.set_logging_level(log, nil)
      log.level.should eq(Logger::WARN)
      subject.set_logging_level(log, '')
      log.level.should eq(Logger::WARN)
    end
    
    it "will error when the level is not recognised" do
      log = Logger.new(STDOUT)
      expect { subject.set_logging_level(log, "argh") }.to raise_exception
    end
  end
  
  context "#init_logging" do
    it "will initialize when everything works" do
      Logger.should_receive(:new).with(:resolved_path, 'daily').and_return(:logger)
      subject.should_receive(:resolve_logging_path).with(:path).and_return(:resolved_path)
      subject.should_receive(:set_logging_level).with(:logger, "debug").and_return(nil)
      subject.init_logging(:path, "debug")
    end
    
    it "will skip logging if the log path is nil" do
      subject.init_logging(nil, "debug")
      subject.init_logging(' ', "debug")
    end
    
    
    it "will error when the logfile cannot be opened" do
      subject.should_receive(:resolve_logging_path).with(:path).and_return(:resolved_path)
      Logger.should_receive(:new).with(:resolved_path, 'daily').and_raise("cannot open")
      expect { subject.init_logging(:path, "debug") }.to raise_exception("Error initializing log file resolved_path: cannot open")
    end
  end
  
  context "#get_pid_path" do
    it "will use /var/run if pid i not specified on command line" do
      subject.get_pid_path({:pid_file=>:pid}).should eq(:pid)
    end
    
    it "will use the command line path if passed" do
      subject.get_pid_path({}).should eq("/var/run/background_queue.pid")
    end
  end
  
  context "#get_pid" do
    it "will return the pid if in the pid file and the process is running" do
      f = double("file", :read=>"123")
      File.should_receive(:open).with(:pid_path).and_yield(f)
      Process.should_receive(:kill).with(0, 123).and_return(nil)
      subject.get_pid({:pid_file=>:pid_path}).should eq(123)
    end
    
    it "will return nil if the pid file does not exist" do
      File.should_receive(:open).with(:pid_path).and_raise("file not found")
      subject.get_pid({:pid_file=>:pid_path}).should be_nil
    end
    
    it "will return nil if the process is not running" do
      f = double("file", :read=>"123")
      File.should_receive(:open).with(:pid_path).and_yield(f)
      Process.should_receive(:kill).with(0, 123).and_raise("not running")
      subject.get_pid({:pid_file=>:pid_path}).should be_nil
    end
    
    it "will return nil if the pid is 0" do
      f = double("file", :read=>"")
      File.should_receive(:open).with(:pid_path).and_yield(f)
      subject.get_pid({:pid_file=>:pid_path}).should be_nil
    end
  end
  
  context "#check_not_running" do
    it "will return if the pid is nil" do
      subject.should_receive(:get_pid).and_return(nil)
      subject.check_not_running({})
    end
    
    it "will raise an error if the pid is not nil" do
      subject.should_receive(:get_pid).and_return(123)
      expect { subject.check_not_running({}) }.to raise_exception("Process 123 already running")
    end
  end
  
  context "#kill_pid" do
    it "will do nothing if the pid is nil" do
      subject.should_receive(:get_pid).and_return(nil)
      subject.kill_pid({})
    end
    
    it "will kill the pid if it exists" do
      subject.should_receive(:get_pid).and_return(123)
      Process.should_receive(:kill).with(9, 123).and_return(nil)
      subject.kill_pid({})
    end
  end
  
  context "#write_pid" do
    before do
      Process.should_receive(:pid).and_return(123)
    end
    it "will write the pid file with the current process id" do
      f = double("file")
      f.should_receive("write").with("123")
      File.should_receive(:open).with(:pid, "w").and_yield(f)
      subject.write_pid({:pid_file=>:pid})
    end
    
    it "will error if the pid file cannot be opened" do
      File.should_receive(:open).with(:pid, "w").and_raise("permission denied")
      expect { subject.write_pid({:pid_file=>:pid}) }.to raise_exception("Unable to write to pid file pid: permission denied") 
    end
  end
  
  context "#remove_pid" do
    it "will remove the file if it exists" do
      File.should_receive(:delete).with(:pid)
      subject.remove_pid({:pid_file=>:pid})
    end
    
    it "will do nothing if the pid file does not exist" do
      File.should_receive(:delete).with(:pid).and_raise("aaarrrgggghhh")
      subject.remove_pid({:pid_file=>:pid})
    end
  end
  
  context "#start" do
    it "will load configuration, init logging then deamonise" do
      subject.should_receive(:load_configuration).and_return(nil)
      subject.should_receive(:init_logging).and_return(nil)
      subject.should_receive(:check_not_running).and_return(nil)
      subject.should_receive(:write_pid).and_return(nil)
      subject.should_receive(:daemonize).and_return(nil)
      subject.start({:command=>:start})
    end
    
    it "will load configuration, init logging then run directly" do
      subject.should_receive(:load_configuration).and_return(nil)
      subject.should_receive(:init_logging).and_return(nil)
      subject.should_receive(:check_not_running).and_return(nil)
      subject.should_receive(:write_pid).and_return(nil)
      subject.should_receive(:run).and_return(nil)
      subject.should_not_receive(:daemonize)
      subject.start({:command=>:run})
    end
    
    it "will display any error and exit" do
      subject.should_receive(:load_configuration).and_raise("some_error")
      STDERR.should_receive(:puts).with("some_error")
      subject.start({:command=>:run})
    end
  end
end
