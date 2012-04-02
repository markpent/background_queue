module BackgroundQueue
  module Utils
    def self.get_hash_entry(hash, key)
      if hash.has_key?(key)
        hash[key]
      elsif key.kind_of?(String)
        hash[key.intern]
      else
        hash[key.to_s]
      end
    end
    
    class AnyKeyHash
      attr_accessor :hash
      
      def initialize(hash)
        @hash = hash
      end
      
      def [] (key)
        BackgroundQueue::Utils.get_hash_entry(@hash, key)
      end
    end
  end
end
