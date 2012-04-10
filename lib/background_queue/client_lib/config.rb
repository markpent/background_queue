require "erb"
require "yaml"

module BackgroundQueue::ClientLib

  #The client configuration which is stored as a YAML file containing a root key for each environments configuration, much like database.yml.
  #
  #Example
  #=======
  #
  #   development:
  #     server:
  #       host: 127.0.0.1
  #       port: 3000
  #     memcache: 127.0.0.1:9999
  #   production:
  #     server: 
  #       host: 192.168.3.56
  #       port: 3000
  #     failover: 
  #       -
  #         host: 192.168.3.57
  #         port: 3000
  #       -
  #         host: 192.168.3.58
  #     memcache: 192.168.3.1:9999, 192.168.3.3:9999
  class Config < BackgroundQueue::Config
    
    #the default port that is used if the configuration does not specify a port
    DEFAULT_PORT = 2222
    
    #the primary {BackgroundQueue::Config::Server}
    attr_reader :server
    #an array of failover {BackgroundQueue::Config::Server}
    attr_reader :failover
    #an array of Strings defining memcache server address
    attr_reader :memcache
    
    #load the configration using a hash just containing the environment
    def self.load_hash(env_config, path)
      BackgroundQueue::ClientLib::Config.new(
        build_primary_server_entry(env_config, path),
        build_failover_server_entries(env_config, path),
        build_memcache_array(env_config, path)
      )
    end
    
    class << self
      private
      
      def build_primary_server_entry(env_config, path)
        server_entry = BackgroundQueue::Utils.get_hash_entry(env_config, :server)
        if server_entry
          begin
            BackgroundQueue::ClientLib::Config::Server.new(server_entry)
          rescue Exception=>e
            full_path = path.nil? ? '<unknown>' : File.expand_path(path)
            raise BackgroundQueue::LoadError, "Error loading 'server' entry from background queue configuration file #{full_path}: #{e.message}"
          end
        else
          full_path = path.nil? ? '<unknown>' : File.expand_path(path)
          raise BackgroundQueue::LoadError, "Missing 'server' entry in background queue configuration file #{full_path}"
        end
      end
      
      def build_failover_server_entries(env_config, path)
        entries = []
        failover_entry = BackgroundQueue::Utils.get_hash_entry(env_config, :failover)
        if failover_entry && failover_entry.kind_of?(Array)
          failover_entry.each_with_index do |entry, index|
            begin
              entries << BackgroundQueue::ClientLib::Config::Server.new(entry)
            rescue Exception=>e
              full_path = path.nil? ? '<unknown>' : File.expand_path(path)
              raise BackgroundQueue::LoadError, "Error loading 'failover' entry (#{index + 1}) from background queue configuration file #{full_path}: #{e.message}"
            end
          end
        elsif failover_entry
          full_path = path.nil? ? '<unknown>' : File.expand_path(path)
          raise BackgroundQueue::LoadError, "Error loading 'failover' entries configuration file #{full_path}: invalid data type (#{failover_entry.class.name}), expecting Array"
        end
        entries
      end
      
      def build_memcache_array(env_config, path)
        memcache_entry = BackgroundQueue::Utils.get_hash_entry(env_config, :memcache)
        if memcache_entry && memcache_entry.kind_of?(String)
          memcache_entry.split(',').collect { |entry| entry.strip }.select { |entry| !entry.nil? && entry.length > 0 }
        elsif memcache_entry
          full_path = path.nil? ? '<unknown>' : File.expand_path(path)
          raise BackgroundQueue::LoadError, "Error loading 'memcache' entry in configuration file #{full_path}: invalid data type (#{memcache_entry.class.name}), expecting String (comma separated)"
        else
          full_path = path.nil? ? '<unknown>' : File.expand_path(path)
          raise BackgroundQueue::LoadError, "Missing 'memcache' entry in configuration file #{full_path}"
        end
      end
    end
    
    
    #do not call this directly, use a load_* method
    def initialize(server, failover, memcache)
      @server = server
      @failover = failover
      @memcache = memcache
    end
    
    #A server entry in the configuration
    class Server
      
      attr_reader :host
      attr_reader :port
      
      def initialize(config_entry)
        if config_entry.kind_of?(Hash)
          @host = BackgroundQueue::Utils.get_hash_entry(config_entry, :host)
          raise BackgroundQueue::LoadError, "Missing 'host' configuration entry" if @host.nil?
        
          @port = BackgroundQueue::Utils.get_hash_entry(config_entry, :port)
          if @port
            @port = @port.to_i
          else
            @port = DEFAULT_PORT 
          end
        else
          raise BackgroundQueue::LoadError, "Invalid data type (#{config_entry.class.name}), expecting Hash"
        end
      end
    end
  end
  
end
