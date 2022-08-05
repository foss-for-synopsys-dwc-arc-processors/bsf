require_relative './config.rb'
require_relative './directory_manager.rb'
require_relative './git_manager.rb'
require_relative './status_manager.rb'
require_relative './var_manager.rb'
require_relative './build.rb'
require_relative './compare.rb'
require 'json'
require 'erb'
require 'git'
module Manager
  
  $SOURCE = Dir.getwd
  $FRAMEWORK = ".bla"
  
  class Manager
    def initialize
      @var_manager = Var_Manager::Var_Manager.new()
      @git_manager = Git_Manager::Git_Manager.new()
      @status_manager = Status_Manager::Status_Manager.new()
    end
    
    def init(file)
      Config::Config.new(file, @var_manager)
    end

    def save_config(path_to_save)
      Config::Config.new.save_config(path_to_save)
    end    
    def clone(repo)
      @git_manager.get_clone_framework(repo)
    end
    
    def clean()
      system "echo Clearing Tasts Folder ; rm -rf #{$SOURCE}/#{$FRAMEWORK}/tests/*"
    end 


    def versions(tool_name)
      cfg = Config::Config.new
      
      internal_params = {}
      internal_params.store(:PREFIX, "#{cfg.config[:params][:PREFIX]}/#{tool_name}")
      to_execute = @var_manager.prepare_data("#{cfg.config[:tasks][tool_name.to_sym][:version_check]}", internal_params)
      system "#{to_execute}"
    end 

    def compare(arr, isJSON)
     
      cfg = Config::Config.new
      compare = Compare::Compare.new

      @git_manager.create_worktree(arr)
      
      dir1 = "#{@git_manager.tmp_dir(0)}/tests"
      dir2 = "#{@git_manager.tmp_dir(1)}/tests"

      tasks = (Dir.children(dir1) & Dir.children(dir2)).select { |d| d =~ /_tests/ }
    
      tasks.each do |task|
        cfg.config[:params].store(:@BASELINE, "#{dir1}/#{task}")
        cfg.config[:params].store(:@REFERENCE, "#{dir2}/#{task}")
        cfg.config[:params].store(:@BUILDNAME, task)
        
        to_execute = @var_manager.prepare_data("#{cfg.config[:tasks][task.to_sym][:comparator]}", cfg.config[:params])       
        json = `#{to_execute}`

        if !isJSON
          compare.main(dir1, dir2, task, JSON.parse(json))
        else 
          puts "\n #{task}: \n #{json}"
        end
      end
      @git_manager.remove_worktree()    
    end

    def search_log(params)
      @git_manager.search_log(params)
    end


    def publish(tool_name)
      cfg = Config::Config.new
      source_dir = "#{$SOURCE}/#{$FRAMEWORK}/tests"
      
      commit_msg_hash = {}
      Dir.children(source_dir).sort.each do |task|
        to_execute = cfg.config[:tasks][task.to_sym][:publish_header]
        tmp = {}

        get_commit_msg(to_execute, tmp) { |command, config | 
          abort("ERROR: Tools version not found") if !system command + "> /dev/null 2>&1"
          commit_msg = JSON.parse(`#{command}`, symbolize_names: true)
          tmp.store(commit_msg[:build_name], commit_msg)
        }

        commit_msg_hash.store(task, tmp)
      end
      @git_manager.publish(JSON.pretty_generate(commit_msg_hash))
    end
   
    def get_commit_msg(to_execute, tmp) 
      return yield(to_execute, tmp) if to_execute.class == String
      to_execute.each { |command| yield(command, tmp) } if to_execute.class == Array
    end

    def internal_git(command)
      @git_manager.internal_git(command)
    end 
    
    def status()  
      abort("ERROR: Nothing built yet") if !system "cat #{@status_manager.path_to_status}"
    end
  
    def var_list()
      @var_manager.var_list(Config::Config.new)
    end
    
    def log(name_version)
      path_from = "#{$SOURCE}/#{$FRAMEWORK}/logs/#{name_version}.log"
      abort("ERROR: Tool not found") if !system "cat #{path_from}"
    end
  
    def repo_list()
      @git_manager.get_repo_list()
    end
  
    def build(filter = nil)
      cfg = Config::Config.new
      git_manager = Git_Manager::Git_Manager.new
      dir_manager = Directory_Manager::Directory_Manager.new
  
      Build::Build.new(cfg, git_manager, dir_manager, @var_manager, @status_manager, filter)
    end

    def set(str)
      cfg = Config::Config.new()
      command = str.split('=').first
      path = str.split('=').last
    
      abort("ERROR: not a editable variable") if command =~/[\@]/
      abort("ERROR: #{command} not a variable") if !@var_manager.verify_if_var_exists(cfg.config, command)
    
      params = cfg.config[:params]
      params.store(command.to_sym, "#{path}")
      cfg.config.store(:params, params)
    
      cfg.set_json()
    end
  
    def help()
      puts <<-EOF
      EOF
    end
  
  end
end
