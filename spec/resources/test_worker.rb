class TestWorker < BackgroundQueue::Worker::Base

  def run
    set_progress("Not Yet..", 50)
    set_progress("Not Yet..", 75)
    set_progress("Done", 100)
  end
end
