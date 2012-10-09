# background_queue

This is a gem to manage background tasks. The primary focus is organising the tasks so they will not overload the machine(s) running the tasks, while
still giving a fair, balanced allocation of running time to members in the queue.


## Usage

### Initializing
In your environment, initialize a constant BackgroundQueue::Client

     BG_QUEUE = BackgroundQueue::Client.new(_PATH_TO_CONFIG_)
 
### Starting a single task
Now you can use your BG\_QUEUE to add a single task. Note: the "task_id" should be unique, even between owners/jobs. If there is an existing task with the same id in any queue,
even if its a different owner/job, the existing task will be removed before this task is added the the ownerjob queue.

     job_handle = BG_QUEUE.add_task(:worker_name, "owner identifier", "job identifier", "task_id", priority, {:some_task=>:params}, {:priority=>1})
  
  
### Starting multiple tasks
Or you can queue multiple tasks at once. 

     job_handle = BG_QUEUE.add_tasks(:worker_name, "owner identifier", "job identifier", [["task1_id" , {:some_task=>:params}], ["task2_id" , {:some_task=>:params}]], priority, {:shared=>:params}, {:priority=>1})

### Job Status
Get the status of the job

    status = BG_QUEUE.get_status(job_handle)


## Queue Management
* Each task on the queue is associated with an 'owner', 'job' and 'id'
* Each job has a priority (0=highest).
* An 'owner' has a queue of 'job' which is a list of tasks.
* Status is tracked per job.
* Tasks within a job can be weighted.

### Finding the next task to run
1. Get the next owner with the highest priority subject
2. Get the next job within the above owner with the highest priority
3. Pop the next task off the job queue.
4. Push the job to the end of the owners job queue.
5. Push the owner to the end of the queue.

## Worker Managment
* The actual workers are implimented using passenger.
* The queue calls the passenger server(s) through HTTP.
* The queue limits the number of simultaneous workers at any one time.
* Using passenger to manage the workers means workers are efficiently re-used, with a full Rails enviroment loaded and ready to go.
* The status of the task is streamed to the queue manager. 



## Contributing to background_queue
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2012 MarkPent. See LICENSE.txt for
further details.

