require 'uri'
require 'ipaddress'

module BackgroundQueue::ServerLib

  #The server configuration which is stored as a YAML file containing a root key for each environments configuration, much like database.yml.
  #
  #Example
  #=======
  #
  #   development:
  #     address: 
  #       host: 127.0.0.1
  #       port: 3000
  #     workers: 
  #       - http://127.0.0.1:801/background_queue
  #     secret: this_is_used_to_make_sure_it_is_secure
  #   production:
  #     address: 
  #       host: 0.0.0.0
  #       port: 3000
  #     connections_per_worker: 10
  #     workers: 
  #       - http://192.168.3.1:801/background_queue
  #       - http://192.168.3.2:801/background_queue
  #     secret: this_is_used_to_make_sure_it_is_secure
  #     system_task_options:
  #       domain: the_default_domain
  #     jobs
  #       - cron: "0 22 * * 1-5"
  #         worker: some_worker
  #         args: 
  #           arg1: 22
  #           arg2: "hello"
  class Config < BackgroundQueue::Config
    
    #the list of workers that are called using http
    attr_reader :workers
    
    
    #the shared secret to make sure the worker is not called directly from the internet
    attr_reader :secret

    #an array of scheduled jobs
    attr_reader :jobs
    
    #the address to listen on
    attr_reader :address
    
    #the number of connections allowed for each active worker
    attr_reader :connections_per_worker
    
    #used for polling task and jobs. Should include a domain entry if your worker uses domain lookups
    attr_reader :system_task_options
    
    #load the configration using a hash just containing the environment
    def self.load_hash(env_config, path)
      BackgroundQueue::ServerLib::Config.new(
        build_worker_entries(env_config, path),
        get_secret_entry(env_config, path),
        get_address_entry(env_config, path),
        get_connections_per_worker_entry(env_config, path),
        get_jobs_entry(env_config, path),
        get_system_task_options_entry(env_config, path)
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
      
      def get_address_entry(env_config, path)
        begin
          BackgroundQueue::ServerLib::Config::Address.new(BackgroundQueue::Utils.get_hash_entry(env_config, :address))
        rescue Exception=>e
          raise BackgroundQueue::LoadError, "Error loading 'address' entry in background queue server configuration file #{full_path(path)}: #{e.message}"
        end
      end
      
      def get_connections_per_worker_entry(env_config, path)
        connections_per_worker_entry = BackgroundQueue::Utils.get_hash_entry(env_config, :connections_per_worker)
        if connections_per_worker_entry && connections_per_worker_entry.kind_of?(Integer)
          connections_per_worker_entry
        elsif connections_per_worker_entry
          raise BackgroundQueue::LoadError, "Error loading 'connections_per_worker' entry in background queue server configuration file #{full_path(path)}: invalid data type (#{connections_per_worker_entry.class.name}), expecting Integer"
        else
          raise BackgroundQueue::LoadError, "Missing 'connections_per_worker' entry in background queue server configuration file #{full_path(path)}"
        end
      end
      
      def get_system_task_options_entry(env_config, path)
        opts_entry = BackgroundQueue::Utils.get_hash_entry(env_config, :system_task_options)
        return {} if opts_entry.nil?
        if opts_entry.kind_of?(Hash)
          opts_entry
        else
          raise BackgroundQueue::LoadError, "Error loading 'system_task_options' entry in background queue server configuration file #{full_path(path)}: invalid data type (#{opts_entry.class.name}), expecting Hash (of options)"
        end
      end

      def get_jobs_entry(env_config, path)
        jobs_entry = BackgroundQueue::Utils.get_hash_entry(env_config, :jobs)
        return [] if jobs_entry.nil?
        if jobs_entry.kind_of?(Array)
          retval = []
          for job in jobs_entry
            begin
              retval << BackgroundQueue::ServerLib::Config::Job.new(job)
            rescue Exception=>e
              raise BackgroundQueue::LoadError, "Error loading 'jobs' entry in background queue server configuration file #{full_path(path)}: #{e.message}"
            end
          end
          retval
        else
          raise BackgroundQueue::LoadError, "Error loading 'jobs' entry in background queue server configuration file #{full_path(path)}: invalid data type (#{jobs_entry.class.name}), expecting Array (of jobs)"
        end
      end
    end
    
    
    #do not call this directly, use a load_* method
    def initialize(workers, secret, address, connections_per_worker, jobs, system_task_options)
      @workers = workers
      @secret = secret
      @address = address
      @connections_per_worker = connections_per_worker
      @jobs = jobs
      @system_task_options = system_task_options
    end
    
    class Address
      attr_reader :host
      attr_reader :port
      
      
      def initialize(config_entry)
        if config_entry.nil? 
          @host = "0.0.0.0"
          @port = BackgroundQueue::Config::DEFAULT_PORT
        else
          port = BackgroundQueue::Utils.get_hash_entry(config_entry, :port)
          if port.nil?
            @port = BackgroundQueue::Config::DEFAULT_PORT
          elsif port.kind_of?(Numeric)
            @port = port.to_i
          elsif port.kind_of?(String)
            if port.to_s.strip == port.to_s.to_i.to_s
              @port = port.to_i
            else
              raise "Invalid port: #{port}"
            end
          else
            raise "Invalid port: should be number or string"
          end
          if @port <= 0
            raise "Invalid port: must be greater then zero"
          end
          host = BackgroundQueue::Utils.get_hash_entry(config_entry, :host)
          if host.nil?
            @host = "0.0.0.0"
          elsif host.kind_of?(String)
            if IPAddress.valid? host
              @host = host
            else
              raise "Invalid host: #{host}"
            end
          else
            raise "Invalid host: should be string"
          end
        end
      end
      
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
    
    class Job
      
      
      attr_accessor :at
      attr_accessor :in
      attr_accessor :cron
      attr_accessor :every
      attr_accessor :type
      attr_accessor :args
      
      def initialize(job_entry)
        raise "Empty Job Entry" if job_entry.nil?
        @at = BackgroundQueue::Utils.get_hash_entry(job_entry, :at)
        @in = BackgroundQueue::Utils.get_hash_entry(job_entry, :in)
        @cron = BackgroundQueue::Utils.get_hash_entry(job_entry, :cron)
        @every = BackgroundQueue::Utils.get_hash_entry(job_entry, :every)
        if !@at.nil?
          @type = :at
        elsif !@in.nil?
          @type = :in
        elsif !@cron.nil?
          @type=:cron
        elsif !@every.nil?
          @type=:every
        else
          raise "Job is missing timer designation (at, in or cron)"
        end
        @worker = BackgroundQueue::Utils.get_hash_entry(job_entry, :worker)
        raise "Job is missing worker entry" if @worker.nil?
        
        @args = {}
        args_entry = BackgroundQueue::Utils.get_hash_entry(job_entry, :args)
        unless args_entry.nil?
          raise "Invalid 'args' entry in job: expecting Hash of arguments, got #{args_entry.class.name}" unless args_entry.kind_of?(Hash)
          @args = args_entry
        end
        
      end
      
      def schedule(scheduler, server)
        case @type
        when :at
          scheduler.at @at do
            run(server)
          end
        when :in
          scheduler.in @in do
            run(server)
          end
        when :cron
          scheduler.cron @cron do
            run(server)
          end
        when :every
          scheduler.every @every do
            run(server)
          end
        end
      end
      
      def run(server)
        task = BackgroundQueue::ServerLib::Task.new(:system, :scheduled, self.object_id, 2, @worker, @args, server.config.system_task_options)
        server.task_queue.add_task(task)
      end
      
    end
  end
  
end
