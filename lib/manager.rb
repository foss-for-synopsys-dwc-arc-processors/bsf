require_relative './config.rb'

require_relative './directory_manager.rb'
require_relative './git_manager.rb'
require_relative './var_manager.rb'
require_relative './build.rb'
require_relative './source.rb'
require_relative './helpers.rb'
require 'json'
require 'erb'

$PWD = Dir.getwd

class Manager

  @@instance = nil

  def self.instance
    @@instance = @@instance || Manager.new
    return @@instance
  end
  def initialize()
  end
  
  def save_config(dir_to)
    Config.instance.save_config(dir_to)
  end
  def clone(repo)
    GitManager.get_clone_framework(repo)
  end
  def clean(tasks = nil, skip_flag = nil)
    tasks = Config.instance.tasks.keys if tasks.nil?
    tasks = [tasks] if tasks.class == String
    begin 
      Helper.input_user("Are you sure you want to clean: [y/n]", tasks) if skip_flag.nil?
    rescue Exception => e
      abort("Process terminated by User") if e.message == "ProcessTerminatedByUserException"
    end
    tasks.each { |task| DirManager.clean_tasks_folder(task) }
    Helper.reset_status()
  end
  def tasks_list()
#    puts Config.instance.tasks.keys
    to_print = ""
    Config.instance.tasks.keys.each do |task|
	to_print += "#{task}:\n    Description: #{Config.instance.task_description(task)}\n\n"
    end
    return to_print
  end

  def get_commit_data(root)
    commit_ids = `cd #{root} ; git rev-list --all`.split("\n").reverse
    current_commit_id = `cd #{root} ; git rev-parse HEAD`.chomp
    previous_commit_id = commit_ids[(commit_ids.find_index(current_commit_id) -1)]
    return { "commit_ids" => commit_ids, "current_commit_id" => current_commit_id, "previous_commit_id" => previous_commit_id }
    return previous_commit_id
  end

  def compare(baseline, reference, options, t = nil)
    to_print = ""
    options = options || ""
    dir1, dir2 = DirManager.get_compare_dir()

    GitManager.create_worktree(baseline, dir1)
    GitManager.create_worktree(reference, dir2) if !reference.nil?
    dir2 = DirManager.get_framework_path if reference.nil?
    dir1 += "/tasks"
    dir2 += "/tasks"

    commit_data1 = get_commit_data(dir1)
    commit_data2 = get_commit_data(dir2)


    json_agregator = {}
    to_execute_commands = {}
    
    is_agregator = t.nil?

    if is_agregator
#        tasks = DirManager.intersect_children_path(dir1, dir2)
#	tasks = (Dir.children(dir1) + Dir.children(dir2)).uniq
        tasks = Config.instance.tasks.keys
    else
        tasks = [t]
    end

    #DEBUG
    tasks.delete(:hs_baremetal_qemu_vs_nsim)


    tasks.each do |task|
        Helper.set_internal_vars(task)

        if File.exists?("#{dir1}/#{task}/.previd")
          previd1 = File.read("#{dir1}/#{task}/.previd").chomp
          if previd1 == 'first'
            baseline_previd_exists = commit_data1["commit_ids"][0] == commit_data1["current_commit_id"]
          else
            baseline_previd_exists = File.read("#{dir1}/#{task}/.previd").chomp == commit_data1["previous_commit_id"]
          end
	else
          baseline_previd_exists = false
        end

        if File.exists?("#{dir2}/#{task}/.previd")
          previd2 = File.read("#{dir2}/#{task}/.previd").chomp
          if previd2 == 'first'
            reference_previd_exists = commit_data2["commit_ids"][0] == commit_data2["current_commit_id"]
          else
            reference_previd_exists = File.read("#{dir2}/#{task}/.previd").chomp == commit_data2["previous_commit_id"]
          end
	else
	  baseline_previd_exists = false
	end
        VarManager.instance.set_internal("@BASELINE", (baseline_previd_exists) ? "#{dir1}/#{task}" : "")
        VarManager.instance.set_internal("@REFERENCE", (reference_previd_exists) ? "#{dir2}/#{task}" : "")
        VarManager.instance.set_internal("@OPTIONS", (is_agregator) ? "-t json" : options)
        
        commands = Config.instance.comparator(task)
       #commands = [commands] if commands.class == String
       #commands.each do |data_to_prepare|
        # to_execute = VarManager.instance.prepare_data(data_to_prepare)
          to_execute = VarManager.instance.prepare_data(commands)
          #system to_execute
          if is_agregator
            json_agregator.merge!(JSON.parse(`#{to_execute}`))
          else
            to_print = `#{to_execute}` 
          end
        # end
    end
    if is_agregator
        VarManager.instance.set_internal("@OPTIONS", options) if !options.nil?
        VarManager.instance.set_internal("@JSON_DEBUG", "'#{(JSON.pretty_generate json_agregator)}'") #
        command = Config.instance.comparator_agregator()
        to_execute = VarManager.instance.prepare_data(command)
        to_print = `#{to_execute}`
    end
    dir1, dir2 = DirManager.get_compare_dir()
    GitManager.remove_worktree(dir1)
    GitManager.remove_worktree(dir2) if !reference.nil?
    return to_print
  end


  def ls(task, commit_id)
    tmp_dir = DirManager.get_worktree_dir()
    to_print = ""
    if commit_id
      GitManager.internal_git("worktree add #{tmp_dir} #{commit_id} > /dev/null 2>&1")
      to_print = `ls #{tmp_dir}/tasks/#{task}`
      GitManager.internal_git("worktree remove #{tmp_dir} > /dev/null 2>&1")
    else

      to_print = `ls #{DirManager.get_persistent_ws_path}/#{task}`
    end
    return to_print
  end

  def cat(task, commit_id, file)
    tmp_dir = DirManager.get_worktree_dir()
    to_print = ""
    if commit_id
      GitManager.internal_git("worktree add #{tmp_dir} #{commit_id}")
      to_print = `cat #{tmp_dir}/tasks/#{task}/#{file}`
      GitManager.internal_git("worktree remove #{tmp_dir}")
    else
      to_print = `cat #{DirManager.get_persistent_ws_path}/#{task}/#{file}`
    end
    return to_print
  end

  def publish()
    persistent_ws = DirManager.get_persistent_ws_path

    commit_msg_hash = {}
    status = JSON.parse(File.read(DirManager.get_status_file))
    Dir.children(persistent_ws).select { |task| status[task] == 0 }.sort.each do |task|
#    Dir.children(persistent_ws).sort.each do |task|
      
      to_execute = Config.instance.publish_header(task)
      
      Helper.set_internal_vars(task)

      to_execute = VarManager.instance.prepare_data(to_execute)
      place_holder = {}
      to_execute = [to_execute] if to_execute.class == String
      to_execute.each do |execute|
#        abort("ERROR: Tools version not found") if !system execute + "> /dev/null 2>&1"
        abort("ERROR: #{execute}") if !system execute
        commit_msg = JSON.parse(`#{execute}`, symbolize_names: true)
        place_holder.merge!(commit_msg)
      end
      
      commit_msg_hash.store(task, place_holder)
    end
    GitManager.publish(JSON.pretty_generate(commit_msg_hash))
  end

  def internal_git(command)
    GitManager.internal_git(command.join(" "))
  end

  def diff(hash1, hash2)
    hash1 = JSON.parse(`cd #{DirManager.get_framework_path} ; git log -n 1 --pretty=format:%s #{hash1}`)
    hash2 = JSON.parse(`cd #{DirManager.get_framework_path} ; git log -n 1 --pretty=format:%s #{hash2}`)
    return JSON.pretty_generate GitManager.diff(hash1, hash2)
  end

  def status(commit_id)
    to_print = ""
    mapping = {
      9 => "Not Executed",
      0 => "Passed",
      1 => "Failed"
    }
    begin
      if !commit_id.nil?
        worktree_dir = DirManager.get_worktree_dir()
        GitManager.internal_git("worktree add #{worktree_dir} #{commit_id}")
        status = Helper.get_status("#{worktree_dir}/status.json")
      else
        status = Helper.get_status
      end
#      status.each_pair { |task, result| to_print += "#{result ? "Passed" : "Failed"}: #{task}\n" }
      status.each_pair { |task, result| to_print += "#{mapping[result]}: #{task}\n" }
      GitManager.internal_git("worktree remove #{worktree_dir}") if !commit_id.nil?
    rescue Exception => e
      abort("ERROR: Nothing executed yet") if e.message == "StatusFileDoesNotExists"
    end
    return to_print
  end

  def log(task, commit_id, is_tail = nil)
    to_print = ""
    worktree_dir = ""
    if !commit_id.nil?
      worktree_dir = DirManager.get_worktree_dir()
      GitManager.internal_git("worktree add #{worktree_dir} #{commit_id}")
      log_file = DirManager.get_log_file_hash(task)
    else
      log_file = DirManager.get_log_file(task)
    end
    puts log_file

    abort("ERROR: Tool not found") if !File.exists? log_file
    if !is_tail.nil?
      system "tail -f #{log_file}"
    else
      to_print = `cat #{log_file}`
    end
    GitManager.internal_git("worktree remove #{worktree_dir}") if !commit_id.nil?
    return to_print
  end

  def repo_list()
    GitManager.get_repo_list()
  end

  def build(filter = nil, skip_flag = nil)
    Build.build(filter, skip_flag)
  end

end
