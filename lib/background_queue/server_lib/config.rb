require 'uri'

module BackgroundQueue::ServerLib

  #The server configuration which is stored as a YAML file containing a root key for each environments configuration, much like database.yml.
  #
  #Example
  #=======
  #
  #   development:
  #     workers: 
  #       - http://127.0.0.1:801/background_queue
  #     memcache: 127.0.0.1:9999
  #     secret: this_is_used_to_make_sure_it_is_secure
  #   production:
  #     workers: 
  #       - http://192.168.3.1:801/background_queue
  #       - http://192.168.3.2:801/background_queue
  #     secret: this_is_used_to_make_sure_it_is_secure
  #     memcache: 192.168.3.1:9999, 192.168.3.3:9999
  class Config < BackgroundQueue::Config
    
    #the list of workers that are called using http
    attr_reader :workers
    
    
    #the shared secret to make sure the worker is not called directly from the internet
    attr_reader :secret

    #an array of Strings defining memcache server address
    attr_reader :memcache
    
    #load the configration using a hash just containing the environment
    def self.load_hash(env_config, path)
      BackgroundQueue::ServerLib::Config.new(
        build_worker_entries(env_config, path),
        get_secret_entry(env_config, path),
        build_memcache_array(env_config, path)
      )
    end
    
    class << self
      private
      
      def build_worker_entries(env_config, path)
        entries = []
        workers_entry = BackgroundQueue::Utils.get_hash_entry(env_config, :workers)
        if workers_entry && workers_entry.kind_of?(Array)
          workers_entry.each_with_index do |entry, index|
            begin
              entries << BackgroundQueue::ServerLib::Config::Worker.new(entry)
            rescue Exception=>e
              raise BackgroundQueue::LoadError, "Error loading 'worker' entry (#{index + 1}) from background queue server configuration file #{full_path(path)}: #{e.message}"
            end
          end
        elsif workers_entry
          raise BackgroundQueue::LoadError, "Error loading 'workers' entries configuration file #{full_path(path)}: invalid data type (#{workers_entry.class.name}), expecting Array"
        else
          raise BackgroundQueue::LoadError, "Missing 'workers' in background queue server configuration file #{full_path(path)}"
        end
        entries
      end
      
      def get_secret_entry(env_config, path)
        secret_entry = BackgroundQueue::Utils.get_hash_entry(env_config, :secret)
        if secret_entry && secret_entry.kind_of?(String)
          secret_entry.strip!
          if secret_entry.length < 20
            raise BackgroundQueue::LoadError, "Error loading 'secret' entry in background queue server configuration file #{full_path(path)}: length too short (must be at least 20 characters long)"
          end
          secret_entry
        elsif secret_entry
          raise BackgroundQueue::LoadError, "Error loading 'secret' entry in background queue server configuration file #{full_path(path)}: invalid data type (#{secret_entry.class.name}), expecting String"
        else
          raise BackgroundQueue::LoadError, "Missing 'secret' entry in background queue server configuration file #{full_path(path)}"
        end
      end
    end
    
    
    #do not call this directly, use a load_* method
    def initialize(workers, secret, memcache)
      @workers = workers
      @secret = secret
      @memcache = memcache
    end
    
    #A server entry in the configuration
    class Worker
      
      attr_reader :uri
      
      def initialize(config_entry)
        if config_entry.nil?
          raise BackgroundQueue::LoadError, "Missing worker url"
        elsif config_entry.kind_of?(String)
          raise BackgroundQueue::LoadError, "Missing worker url" if config_entry.strip.length == 0
          begin
            @uri = URI.parse(config_entry)
          rescue URI::InvalidURIError
            raise BackgroundQueue::LoadError, "Invalid worker url (#{config_entry})"
          end
        else
          raise BackgroundQueue::LoadError, "Invalid data type (#{config_entry.class.name}), expecting String (as a url)"
        end
      end
      
      def url
        @uri.to_s
      end
    end
  end
  
end