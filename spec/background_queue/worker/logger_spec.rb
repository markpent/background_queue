require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'background_queue_worker'


module ActiveRecord
  class Base
    @@logger = :ar_logger
    
    def self.logger
      @@logger
    end
    
    def self.logger=(other)
      @@logger = other
    end
  end
end

describe BackgroundQueue::Worker::Logger do
  
  let(:faux_logger) {
    double("logger")
  }

  context "#build_logger" do
    it "will init a logger object" do
      logger = BackgroundQueue::Worker::Logger.build_logger("/tmp/bgq_test1.log", "task_key", Logger::DEBUG)
    end
  end
  
  context "#init_logger" do
    it "will reset the system loggers" do
      BackgroundQueue::Utils.should_receive(:current_root).and_return("ROOT")
      BackgroundQueue::Worker::Logger.should_receive(:build_logger).with("ROOT/log/workers/worker_name-owner_key-job_key.log", "task_key", :level).and_return(faux_logger)
      
      faux_logger.should_receive(:set_previous_state).with({:ar_base=>:ar_logger, :rails_default_logger=>:abc})
      
      RAILS_DEFAULT_LOGGER = :abc
      
      logger = BackgroundQueue::Worker::Logger.init_logger("worker_name", "owner_key", "job_key", "task_key", :level)
      
      RAILS_DEFAULT_LOGGER.should be(logger)
      ActiveRecord::Base.logger.should be(logger)
      
    end
  end
  
  context "#revert_to_previous_state" do
    it "will set the state back" do
      logger = BackgroundQueue::Worker::Logger.new("/tmp/bgq_test1.log", "task_key")
      logger.set_previous_state({:ar_base=>:ar_logger1, :rails_default_logger=>:abc1})
      logger.revert_to_previous_state
      RAILS_DEFAULT_LOGGER.should be(:abc1)
      ActiveRecord::Base.logger.should be(:ar_logger1)
    end
  end
    
end
