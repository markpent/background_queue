module BackgroundQueue
  class Client
    
    attr_accessor :config
    
    def initialize(path)
      @config = BackgroundQueue::Config.load_file(path)
    end
  end
end
