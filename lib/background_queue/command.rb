require 'json'

module BackgroundQueue

  #store a command and all its parameters as a hash to be serialized when passing to/from the server.
  class Command

    attr_accessor :code
    attr_accessor :options
    attr_accessor :args
    
    def initialize(code, options, args)
      @code = code
      @options = BackgroundQueue::Utils::AnyKeyHash.new(options)
      @args = BackgroundQueue::Utils::AnyKeyHash.new(args)
    end
    
    #convert the command to a string (currently json) to get sent
    def to_buf
      {:c=>@code, :a=>@args.hash, :o=>@options.hash}.to_json
    end
    
    #load a command from a string
    def self.from_buf(buf)
      hash_data = nil
      begin
        hash_data = JSON.load(buf)
      rescue Exception=>e
        raise InvalidCommand, "Invalid data format (should be json) when loading command from buffer: #{e.message}"
      end
      begin
        raise "Missing 'c' (code)" if hash_data['c'].nil?
        code = hash_data['c'].intern
        raise "Missing 'a' (args)" if hash_data['a'].nil?
        args = hash_data['a']
        raise "Missing 'o' (options)" if hash_data['o'].nil?
        options = hash_data['o']
        BackgroundQueue::Command.new(code, options, args)
      rescue Exception=>e
        raise InvalidCommand, "Error loading command from buffer: #{e.message}"
      end
    end
  end
  
  #Error raised when command is invalid
  class InvalidCommand < Exception
    
  end
end
