require "erb"
require "yaml"

module BackgroundQueue

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
  class Config
    
    #the default port that is used if the configuration does not specify a port
    DEFAULT_PORT = 2222
    
    #the primary {BackgroundQueue::Config::Server}
    attr_reader :server
    #an array of failover {BackgroundQueue::Config::Server}
    attr_reader :failover
    #an array of Strings defining memcache server address
    attr_reader :memcache
    
    #load the configuration using a file path
    def self.load_file(path)
      string = get_string_from_file(path)
      load_string(string, path)
    end
    
    #load the configuration using a string that may contain ERB syntax
    def self.load_string(string, path)
      evaled_string = evaluate_erb(string, path)
      load_yaml(evaled_string, path)
    end
    
    #load the configuration using a string of YAML
    def self.load_yaml(yaml_string, path)
      all_configs = convert_yaml_to_hash(yaml_string, path)
      env_config = extract_enviroment_entry(all_configs, path)
      load_hash(env_config, path)
    end
    
    #load the configration using a hash just containing the environment
    def self.load_hash(env_config, path)
      BackgroundQueue::Config.new(
        build_primary_server_entry(env_config, path),
        build_failover_server_entries(env_config, path),
        build_memcache_array(env_config, path)
      )
    end
    
    class << self
      private
      
      def get_string_from_file(path)
        if File.exist?(path)
          File.open(path) { |f| f.read }
        else
          #nothing more annoying than not understanding where the library thinks path is pointing to...
          full_path = File.expand_path(path)
          raise BackgroundQueue::LoadError, "Failed to open background_queue configuration file at '#{full_path}'"
        end
      end
      
      def evaluate_erb(string, path)
        begin
          message = ERB.new(string)
          message.result
        rescue Exception=>ex
          full_path = path.nil? ? '<unknown>' : File.expand_path(path)
          raise BackgroundQueue::LoadError, "Error executing ERB for background_queue configuration file at '#{full_path}': #{ex.message}"
        end
      end
      
      
      
      def convert_yaml_to_hash(string, path)
        begin
          result = YAML::load(string)
          raise "Root of config should be a hash of environment configurations" unless result.kind_of?(Hash)
          result
        rescue Exception=>ex
          full_path = path.nil? ? '<unknown>' : File.expand_path(path)
          raise BackgroundQueue::LoadError, "Error loading YAML for background_queue configuration file at '#{full_path}': #{ex.message}"
        end
      end
      
      def current_environment
        if ENV.has_key?('RAILS_ENV')
          ENV['RAILS_ENV']
        elsif defined? Rails
          Rails.env
        end
      end
      
      def extract_enviroment_entry(all_configs, path)
        env_str = current_environment
        if all_configs.has_key?(env_str)
          all_configs[env_str]
        elsif all_configs.has_key?(env_str.to_s.intern)
          all_configs[env_str.to_s.intern]
        else
          full_path = path.nil? ? '<unknown>' : File.expand_path(path)
          raise BackgroundQueue::LoadError, "Error loading YAML for background_queue configuration file at '#{full_path}': missing enviroment root entry: #{env_str}"
        end
      end
      
      
      
      def build_primary_server_entry(env_config, path)
        server_entry = BackgroundQueue::Utils.get_hash_entry(env_config, :server)
        if server_entry
          begin
            BackgroundQueue::Config::Server.new(server_entry)
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
              entries << BackgroundQueue::Config::Server.new(entry)
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
  
  #Error raised when unable to load configuration
  class LoadError < Exception

  end
end
