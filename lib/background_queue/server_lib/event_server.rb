require 'eventmachine'
require 'rubygems'
require 'rufus/scheduler'

module BackgroundQueue::ServerLib
  class EventServer
    
    attr_reader :running
    
    def initialize(server)
      @server = server
      @running = false
    end
    
    def start
      EventMachine.run do
        EventMachine::start_server(@server.config.address.host, @server.config.address.port, BackgroundQueue::ServerLib::EventConnection) do |conn|
          conn.server = @server
        end

        @scheduler = Rufus::Scheduler::EmScheduler.new
        @scheduler.start
        for job in @server.config.jobs
          job.schedule(@scheduler, @server)
        end
        @running = true
      end
      @running = false
    end
    
    def stop
      EventMachine::stop if EventMachine::reactor_running?
    end
  end
end
