require "erb"
require "yaml"

module BackgroundQueue
  class Config
    DEFAULT_PORT = 2222
    
    def self.get_hash_entry(hash, key)
      if hash.has_key?(key)
        hash[key]
      elsif key.kind_of?(String)
        hash[key.intern]
      else
        hash[key.to_s]
      end
    end
    
    def self.get_string_from_file(path)
      if File.exist?(path)
        File.open(path) { |f| f.read }
      else
        #nothing more annoying than not understanding where the library thinks path is pointing to...
        full_path = File.expand_path(path)
        raise BackgroundQueue::LoadError, "Failed to open background_queue configuration file at '#{full_path}'"
      end
    end
    
    def self.load_file(path)
      string = get_string_from_file(path)
      load_string(string, path)
    end
    
    def self.evaluate_erb(string, path)
      begin
        message = ERB.new(string)
        message.result
      rescue Exception=>ex
        full_path = path.nil? ? '<unknown>' : File.expand_path(path)
        raise BackgroundQueue::LoadError, "Error executing ERB for background_queue configuration file at '#{full_path}': #{ex.message}"
      end
    end
    
    def self.load_string(string, path)
      evaled_string = evaluate_erb(string, path)
      load_yaml(evaled_string, path)
    end
    
    def self.convert_yaml_to_hash(string, path)
      begin
        result = YAML::load(string)
        raise "Root of config should be a hash of environment configurations" unless result.kind_of?(Hash)
        result
      rescue Exception=>ex
        full_path = path.nil? ? '<unknown>' : File.expand_path(path)
        raise BackgroundQueue::LoadError, "Error loading YAML for background_queue configuration file at '#{full_path}': #{ex.message}"
      end
    end
    
    def self.current_environment
      if ENV.has_key?('RAILS_ENV')
        ENV['RAILS_ENV']
      elsif defined? Rails
        Rails.env
      end
    end
    
    def self.extract_enviroment_entry(all_configs, path)
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
    
    def self.load_yaml(yaml_string, path)
      all_configs = convert_yaml_to_hash(yaml_string, path)
      env_config = extract_enviroment_entry(all_configs, path)
      load_hash(env_config, path)
    end
    
    def self.build_primary_server_entry(env_config, path)
      server_entry = BackgroundQueue::Config.get_hash_entry(env_config, :server)
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
    
    def self.build_failover_server_entries(env_config, path)
      entries = []
      failover_entry = BackgroundQueue::Config.get_hash_entry(env_config, :failover)
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
    
    def self.build_memcache_array(env_config, path)
      memcache_entry = BackgroundQueue::Config.get_hash_entry(env_config, :memcache)
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
    
    def self.load_hash(env_config, path)
      BackgroundQueue::Config.new(
        build_primary_server_entry(env_config, path),
        build_failover_server_entries(env_config, path),
        build_memcache_array(env_config, path)
      )
    end
    
    
    attr_reader :server
    attr_reader :failover
    attr_reader :memcache
    def initialize(server, failover, memcache)
      @server = server
      @failover = failover
      @memcache = memcache
    end
    
    class Server
      
      attr_reader :host
      attr_reader :port
      
      def initialize(config_entry)
        if config_entry.kind_of?(Hash)
          @host = BackgroundQueue::Config.get_hash_entry(config_entry, :host)
          raise BackgroundQueue::LoadError, "Missing 'host' configuration entry" if @host.nil?
        
          @port = BackgroundQueue::Config.get_hash_entry(config_entry, :port)
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
  
  class LoadError < Exception

  end
end
