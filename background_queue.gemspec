# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "background_queue"
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["MarkPent"]
  s.date = "2012-10-09"
  s.description = "Organise background tasks so they will not overload the machine(s) running the tasks, while still giving a fair, balanced allocation of running time to members in the queue"
  s.email = "mark.pent@gmail.com"
  s.executables = ["bg_queue"]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md",
    "TODO"
  ]
  s.files = [
    ".document",
    ".rspec",
    ".rvmrc",
    "Gemfile",
    "LICENSE.txt",
    "README.md",
    "Rakefile",
    "TODO",
    "VERSION",
    "background_queue.gemspec",
    "bin/bg_queue",
    "lib/background_queue.rb",
    "lib/background_queue/client.rb",
    "lib/background_queue/client_lib/command.rb",
    "lib/background_queue/client_lib/config.rb",
    "lib/background_queue/client_lib/connection.rb",
    "lib/background_queue/client_lib/job_handle.rb",
    "lib/background_queue/command.rb",
    "lib/background_queue/config.rb",
    "lib/background_queue/server_lib/balanced_queue.rb",
    "lib/background_queue/server_lib/config.rb",
    "lib/background_queue/server_lib/event_connection.rb",
    "lib/background_queue/server_lib/event_server.rb",
    "lib/background_queue/server_lib/job.rb",
    "lib/background_queue/server_lib/job_registry.rb",
    "lib/background_queue/server_lib/lru.rb",
    "lib/background_queue/server_lib/owner.rb",
    "lib/background_queue/server_lib/priority_queue.rb",
    "lib/background_queue/server_lib/queue_registry.rb",
    "lib/background_queue/server_lib/server.rb",
    "lib/background_queue/server_lib/sorted_workers.rb",
    "lib/background_queue/server_lib/task.rb",
    "lib/background_queue/server_lib/task_registry.rb",
    "lib/background_queue/server_lib/thread_manager.rb",
    "lib/background_queue/server_lib/worker.rb",
    "lib/background_queue/server_lib/worker_balancer.rb",
    "lib/background_queue/server_lib/worker_client.rb",
    "lib/background_queue/server_lib/worker_thread.rb",
    "lib/background_queue/utils.rb",
    "lib/background_queue/worker/base.rb",
    "lib/background_queue/worker/calling.rb",
    "lib/background_queue/worker/config.rb",
    "lib/background_queue/worker/environment.rb",
    "lib/background_queue/worker/worker_loader.rb",
    "lib/background_queue_server.rb",
    "lib/background_queue_worker.rb",
    "spec/background_queue/client_lib/command_spec.rb",
    "spec/background_queue/client_lib/config_spec.rb",
    "spec/background_queue/client_lib/connection_spec.rb",
    "spec/background_queue/client_spec.rb",
    "spec/background_queue/command_spec.rb",
    "spec/background_queue/config_spec.rb",
    "spec/background_queue/server_lib/balanced_queue_spec.rb",
    "spec/background_queue/server_lib/config_spec.rb",
    "spec/background_queue/server_lib/event_connection_spec.rb",
    "spec/background_queue/server_lib/event_server_spec.rb",
    "spec/background_queue/server_lib/integration/full_test_spec.rb",
    "spec/background_queue/server_lib/integration/queue_integration_spec.rb",
    "spec/background_queue/server_lib/integration/serialize_spec.rb",
    "spec/background_queue/server_lib/job_registry_spec.rb",
    "spec/background_queue/server_lib/job_spec.rb",
    "spec/background_queue/server_lib/owner_spec.rb",
    "spec/background_queue/server_lib/priority_queue_spec.rb",
    "spec/background_queue/server_lib/server_spec.rb",
    "spec/background_queue/server_lib/sorted_workers_spec.rb",
    "spec/background_queue/server_lib/task_registry_spec.rb",
    "spec/background_queue/server_lib/task_spec.rb",
    "spec/background_queue/server_lib/thread_manager_spec.rb",
    "spec/background_queue/server_lib/worker_balancer_spec.rb",
    "spec/background_queue/server_lib/worker_client_spec.rb",
    "spec/background_queue/server_lib/worker_thread_spec.rb",
    "spec/background_queue/utils_spec.rb",
    "spec/background_queue/worker/base_spec.rb",
    "spec/background_queue/worker/calling_spec.rb",
    "spec/background_queue/worker/environment_spec.rb",
    "spec/background_queue/worker/worker_loader_spec.rb",
    "spec/background_queue_spec.rb",
    "spec/resources/config-client.yml",
    "spec/resources/config-serialize.yml",
    "spec/resources/config.yml",
    "spec/resources/example_worker.rb",
    "spec/resources/example_worker_with_error.rb",
    "spec/resources/test_worker.rb",
    "spec/shared/queue_registry_shared.rb",
    "spec/spec_helper.rb",
    "spec/support/default_task.rb",
    "spec/support/private.rb",
    "spec/support/simple_server.rb",
    "spec/support/simple_task.rb",
    "spec/support/test_worker_server.rb"
  ]
  s.homepage = "http://github.com/markpent/background_queue"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.17"
  s.summary = "Background processing"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<json>, [">= 0"])
      s.add_runtime_dependency(%q<rufus-scheduler>, [">= 0"])
      s.add_runtime_dependency(%q<eventmachine>, ["~> 0.12.10"])
      s.add_runtime_dependency(%q<ipaddress>, ["~> 0.8.0"])
      s.add_development_dependency(%q<rspec>, [">= 2.9.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.8.3"])
      s.add_development_dependency(%q<yard>, ["~> 0.7"])
      s.add_development_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_development_dependency(%q<redcarpet>, ["~> 2.1.1"])
    else
      s.add_dependency(%q<json>, [">= 0"])
      s.add_dependency(%q<rufus-scheduler>, [">= 0"])
      s.add_dependency(%q<eventmachine>, ["~> 0.12.10"])
      s.add_dependency(%q<ipaddress>, ["~> 0.8.0"])
      s.add_dependency(%q<rspec>, [">= 2.9.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.8.3"])
      s.add_dependency(%q<yard>, ["~> 0.7"])
      s.add_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_dependency(%q<redcarpet>, ["~> 2.1.1"])
    end
  else
    s.add_dependency(%q<json>, [">= 0"])
    s.add_dependency(%q<rufus-scheduler>, [">= 0"])
    s.add_dependency(%q<eventmachine>, ["~> 0.12.10"])
    s.add_dependency(%q<ipaddress>, ["~> 0.8.0"])
    s.add_dependency(%q<rspec>, [">= 2.9.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.8.3"])
    s.add_dependency(%q<yard>, ["~> 0.7"])
    s.add_dependency(%q<rdoc>, ["~> 3.12"])
    s.add_dependency(%q<bundler>, ["~> 1.0.0"])
    s.add_dependency(%q<redcarpet>, ["~> 2.1.1"])
  end
end
