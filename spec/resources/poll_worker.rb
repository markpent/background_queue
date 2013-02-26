class PollWorker < BackgroundQueue::Worker::Base

  def run
    environment.controller.test_server.is_polling_call = true
    set_progress("Done", 100)
  end
end
