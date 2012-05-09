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

  end
end
