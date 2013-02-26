class SimpleWorker < BackgroundQueue::Worker::Base

  def run
    set_progress("Done", 100)
  end
end
