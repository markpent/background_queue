require "erb"
require "yaml"

module BackgroundQueue
  class Config
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
  end
  
  class LoadError < Exception

  end
end
