require 'eventmachine'

module BackgroundQueue::ServerLib
  class EventConnection < EventMachine::Connection
    
    attr_accessor :server
    
    STAGE_LENGTH = 0
    STAGE_BODY = 1
    
    MAX_BODY_LENGTH = 9999999
    
    
    def initialize
      @data = ""
      @length = 0
      @stage = STAGE_LENGTH
    end
    
    def receive_data(data)
      @data << data
      if @stage == STAGE_LENGTH
        if @data.length >= 6
          s_header = @data.slice!(0,6)
          version, length = s_header.unpack("SL")
          
          if version == 1
            @length = length
            @stage = STAGE_BODY
            if length > MAX_BODY_LENGTH || length <= 0
              raise "Invalid length: #{length}"
            end
          else
            raise "Invalid header version: #{version}"
          end
        end
      end
      
      if @stage == STAGE_BODY && @data.length == @length
        #body received
        process_data(@data)
      end
    end
    
    def process_data(data)
      
    end
  
  end
end
