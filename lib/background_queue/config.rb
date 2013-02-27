require "erb"
require "yaml"

module BackgroundQueue

  #Base class that loads configuration files for client/server
  class Config
    
    #the default port that is used if the configuration does not specify a port
    DEFAULT_PORT = 2222
    
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
    
    #load the configration using a hash just containing the environment. Overridden by Client/Server class.
    def self.load_hash(env_config, path)
      raise "Invalid Loading of Ciguration using abstract base class. Use Server or Client subclass."
    end
    

    class << self
      private
      
      #nothing more annoying than not understanding where the library thinks path is pointing to...
      def full_path(path)
        if path.nil?
          '<unknown>'
        else
          begin
            File.expand_path(path)
          rescue
            '<unknown>'
          end
        end
      end
      
      def get_string_from_file(path)
        raise BackgroundQueue::LoadError, "No configuration file specified" if path.nil?
        if File.exist?(path)
          File.open(path) { |f| f.read }
        else
          raise BackgroundQueue::LoadError, "Failed to open background_queue configuration file at '#{full_path(path)}'"
        end
      end
      
      def evaluate_erb(string, path)
        begin
          message = ERB.new(string)
          message.result
        rescue Exception=>ex
          raise BackgroundQueue::LoadError, "Error executing ERB for background_queue configuration file at '#{full_path(path)}': #{ex.message}"
        end
      end
      
      def convert_yaml_to_hash(string, path)
        begin
          result = YAML::load(string)
          raise "Root of config should be a hash of environment configurations" unless result.kind_of?(Hash)
          result
        rescue Exception=>ex
          raise BackgroundQueue::LoadError, "Error loading YAML for background_queue configuration file at '#{full_path(path)}': #{ex.message}"
        end
      end
      
      def extract_enviroment_entry(all_configs, path)
        env_str = BackgroundQueue::Utils.current_environment
        if all_configs.has_key?(env_str)
          all_configs[env_str]
        elsif all_configs.has_key?(env_str.to_s.intern)
          all_configs[env_str.to_s.intern]
        else
          raise BackgroundQueue::LoadError, "Error loading YAML for background_queue configuration file at '#{full_path(path)}': missing enviroment root entry: #{env_str}"
        end
      end
      
      def build_memcache_array(env_config, path)
        memcache_entry = BackgroundQueue::Utils.get_hash_entry(env_config, :memcache)
        if memcache_entry && memcache_entry.kind_of?(String)
          memcache_entry.split(',').collect { |entry| entry.strip }.select { |entry| !entry.nil? && entry.length > 0 }
        elsif memcache_entry
          raise BackgroundQueue::LoadError, "Error loading 'memcache' entry in configuration file #{full_path(path)}: invalid data type (#{memcache_entry.class.name}), expecting String (comma separated)"
        else
          raise BackgroundQueue::LoadError, "Missing 'memcache' entry in configuration file #{full_path(path)}"
        end
      end
    end
  end
  
  #Error raised when unable to load configuration
  class LoadError < Exception

  end
end
