#we want a list of workers where the first in the list is the next worker to use.
#the next worker to use is the worker with the least number of running connections

class BackgroundQueue::ServerLib::SortedWorkers

  attr_reader :worker_list
  
  def initialize
    @worker_list = []
  end
  
  #add the worker back in the correct position
  def add_worker(worker)
    idx = 0
    while idx < @worker_list.length && @worker_list[idx].connections < worker.connections
      idx += 1
    end
    if idx == 0
      @worker_list.unshift(worker)
    else
      @worker_list.insert(idx, worker)
    end
  end
  
  def remove_worker(worker)
    @worker_list.delete(worker)
  end
  
  
  def adjust_worker(worker)
    idx = @worker_list.index(worker)
    raise "Worker not found" if idx.nil?
    swap_idx = idx - 1
    while swap_idx >= 0 && @worker_list[swap_idx].connections > worker.connections
      swap_idx -= 1
    end
    swap_idx += 1
    if swap_idx == idx #we didnt move forward, try backwards
      swap_idx = idx + 1
      while swap_idx < @worker_list.length && @worker_list[swap_idx].connections < worker.connections
        swap_idx += 1
      end
      swap_idx -= 1
    end
    if swap_idx != idx
      tmp = @worker_list[swap_idx]
      @worker_list[swap_idx] = @worker_list[idx]
      @worker_list[idx] = tmp
    end
  end
  
end
