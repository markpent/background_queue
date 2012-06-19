module BackgroundQueue
  #Utility Module
  module Utils
    
    #gets an entry from a hash regardless if the key is a string or symbol
    def self.get_hash_entry(hash, key)
      if hash.has_key?(key)
        hash[key]
      elsif key.kind_of?(String)
        hash[key.intern]
      else
        hash[key.to_s]
      end
    end
    
    #class that wraps a hash so it can be accessed by key or symbol
    class AnyKeyHash
      #the wrapped hash
      attr_accessor :hash
      
      #wrap a hash
      def initialize(hash)
        @hash = hash
      end
      
      #get an entry by string or symbol
      def [] (key)
        BackgroundQueue::Utils.get_hash_entry(@hash, key)
      end
      
      def []=(key, value)
        @hash[key] = value
      end
    end
  end
end
