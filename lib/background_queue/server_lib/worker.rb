#this is a worker which keeps track of how many connections are getting used by the worker.
class BackgroundQueue::ServerLib::Worker

  attr_accessor :uri
  attr_accessor :connections
  attr_accessor :offline
  
  def initialize(uri)
    @uri = uri
    @connections = 0
    @offline = false
  end
  
  def offline?
    @offline
  end

end
