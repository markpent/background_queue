module BackgroundQueue::Worker
  #looks after loading and caching worker classes.
  #worker classes sit in BackgroundQueue::Worker::Config.worker_path directory
  class WorkerLoader
    
    def initialize
      @worker_entries = {}
    end
    
    def self.get_worker(worker_name)
      @@worker_loader ||= BackgroundQueue::Worker::WorkerLoader.new
      @@worker_loader.get_worker(worker_name)
    end
  
    def get_worker(worker_name)
      worker_entry = get(worker_name)
      if worker_entry.nil?
        worker_entry = load_worker(worker_name)
        set(worker_entry)
      else
        reload_if_updated(worker_entry)
      end
      worker_entry.worker
    end

    def load_worker(worker_name)
      path = worker_path(worker_name)
      load_file(path)
      datestamp = File.mtime(path)
      worker = load_class(worker_name, path)
      WorkerEntry.new(worker, path, datestamp, worker_name)
    end
    
    def load_file(path)
      load(path)
    end
    
    def load_class(worker_name, path)
      class_name = worker_class_name(worker_name)
      begin
        eval("#{class_name}.new")
      rescue NameError=>e
        raise "#{path} did not define #{class_name}"
      end
    end
   
    def worker_class_name(worker_name)
      worker_name.split('_').collect!{ |w| w.capitalize }.join
    end
    
    def worker_path(worker_name)
      File.join(BackgroundQueue::Worker::Config.worker_path, "#{worker_name}.rb")
    end
    
    def reload_if_updated(worker_entry)
      ds = File.mtime(worker_entry.path)
      if ds != worker_entry.datestamp
        load_file(worker_entry.path)
        worker_entry.worker = load_class(worker_entry.name)
        worker_entry.datestamp = ds
      end
    end
    
    
    
    class WorkerEntry
      
      attr_accessor :worker
      attr_accessor :path
      attr_accessor :datestamp
      attr_accessor :name
      
      def initialize(worker, path, datestamp, name)
        @worker = worker
        @path = path
        @datestamp = datestamp
        @name = name
      end
      
    end
    
    private
    
    def set(worker_entry)
      @worker_entries[worker_entry.name] = worker_entry
    end
    
    def get(worker_name)
      @worker_entries[worker_name]
    end
    
    
  end
end
