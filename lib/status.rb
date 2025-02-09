module Status

  def self.get_task_status(commit_id = nil)
    mapping = {
      9 => "Not Executed",
      0 => "Passed",
      1 => "Failed"
    }

    if commit_id
      Helper.validate_commit_id(commit_id)
      worktree_dir = DirManager.get_worktree_dir()
      GitManager.create_worktree(commit_id, worktree_dir)
      status = get_status("#{worktree_dir}/status.json")
      GitManager.remove_worktree(worktree_dir)
    else
      status = get_status
    end

    status_info = status.map do |task, result|
      result_text = mapping[result]
      "#{result_text}: #{task}"
    end.join("\n")

    return status_info
  end

  def self.set_status(result, task)
    status = get_status()
    data = {}

    mutex = Mutex.new
    mutex.lock
    status[task.to_sym] = result && 0 || 1
    File.write(DirManager.get_status_file, JSON.pretty_generate(status))
    mutex.unlock

    puts (result) ? "Passed" : "Failed"
  end

  def self.get_status(status_path_file = DirManager.get_status_file)
    unless File.exists?(status_path_file)
      raise Ex::StatusFileDoesNotExistsException
    end
    return JSON.parse(File.read(status_path_file), symbolize_names: true)
  end

  def self.reset_status(task = nil)
    status = get_status()
    if task
      status[task.to_sym] = 9
    else
      status.transform_values! { 9 }
    end
    File.write(DirManager.get_status_file, JSON.pretty_generate(status))
  end

  def self.init_status(tasks, status_path_file = DirManager.get_status_file)
    status = {}
    tasks.each do |task|
      status[task] = 9
    end
    File.write(status_path_file, JSON.pretty_generate(status))
  end

end
