class SummaryWorker < BackgroundQueue::Worker::Base

  def run
    begin
      if params[:mode] == "summary"
        raise "Invalid Summary (#{summary.inspect})" if summary[:test] != [1, 2] && summary[:test] != [2, 1]
      else
        raise "Missing TestId" if params[:test_id].nil?
        add_progress_meta(:meta, {:test_meta=>context[:some]})
        append_summary(:test, params[:test_id])
      end
      set_progress("Done", 100)
    rescue Exception=>e
      puts e.message
      puts e.backtrace.join("\n")
    end
  end
end
