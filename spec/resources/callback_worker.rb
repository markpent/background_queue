class CallbackWorker < BackgroundQueue::Worker::Base

  def run
    context[:callback].call(self)
  end
end
