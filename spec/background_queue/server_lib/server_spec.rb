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
      BackgroundQueue::ServerLib::Config.should_receive(:open_file).with(:path).and_return(true)
      subject.load_configuration(:path).should be_true
    end
    
    it "will raise an error if configuration does not load" do
      BackgroundQueue::ServerLib::Config.should_receive(:open_file).with(:path).and_raise("nooo!")
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
    xit "will use /var/run if pid i not specified on command line" do
      
    end
    
    xit "will use the command line path if passed" do
      
    end
  end
  
  context "#get_pid" do
    xit "will return the pid if in the pid file and the process is running" do
      
    end
    
    xit "will return nil if the pid file does not exist" do
      
    end
    
    xit "will return nil if the process is not running" do
      
    end
    
    xit "will return nil if the pid is 0" do
      
    end
  end
  
  context "#check_not_running" do
    xit "will return if the pid is nil" do
      
    end
    
    xit "will raise an error if the pid is not nil" do
      
    end
  end
  
  context "#kill_pid" do
    xit "will do nothing if the pid is nil" do
      
    end
    
    xit "will kill the pid if it exists" do
      
    end
  end
  
  context "write_pid" do
    xit "will write the pid file with the current process id" do
      
    end
    
    xit "will error if the pid file cannot be opened" do
      
    end
  end
  
  context "#remove_pid" do
    xit "will remove the file if it exists" do
      
    end
    
    xit "will do nothing if the pid file does not exist" do
      
    end
  end
  
  context "#daemonize" do
    
  end
  
  context "#start" do
   
    
  end
end
