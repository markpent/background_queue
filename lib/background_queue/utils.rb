module BackgroundQueue
  #Utility Module
  module Utils
    
    def self.current_environment
      if ENV.has_key?('RAILS_ENV')
        ENV['RAILS_ENV']
      elsif defined? Rails
        Rails.env
      end
    end
    
    def self.current_root
      if defined? RAILS_ROOT
        RAILS_ROOT
      elsif defined? Rails
        Rails.root
      end
    end
    
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
        if hash.kind_of?(Hash)
          @hash = hash
        else
          raise "Invalid class used when initializing AnyKeyHash (#{hash.class.name})"
        end
      end
      
      #get an entry by string or symbol
      def [] (key)
        BackgroundQueue::Utils.get_hash_entry(@hash, key)
      end
      
      def []=(key, value)
        @hash[key] = value
      end
      
      def to_json(dummy=true)
        @hash.to_json
      end
      
      def merge(other_map)
        AnyKeyHash.new(@hash.clone.update(other_map))
      end
    end
  end
end
