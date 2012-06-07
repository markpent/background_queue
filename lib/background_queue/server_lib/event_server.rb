require 'eventmachine'

module BackgroundQueue::ServerLib
  class EventServer
    def initialize(server)
      @server = server
    end
    
    def start
      EventMachine.run do
        EventMachine::start_server(@server.config.address.host, @server.config.address.port, BackgroundQueue::ServerLib::EventConnection) do |conn|
          conn.server = @server
        end
      end
    end
    
    def start_jobs
      @scheduler = nil
      EventMachine.run do
        @scheduler = Rufus::Scheduler::EmScheduler.start_new
        for job in @server.config.jobs
          job.schedule(@scheduler, @server)
        end
      end
    end

  end
end
