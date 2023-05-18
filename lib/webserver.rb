require 'sinatra/base'



class WebServer < Sinatra::Base 

  set :default_content_type, 'application/json'


  def handler(message)
    data = JSON.parse(request.body.read, symbolize_names: true)
    begin
      yield data
      { code: 20, message: message }.to_json
    rescue Exception => e
      { code: 22, message: e }.to_json
    end
  end

  def get_handler()
    begin
      yield.to_json
    rescue Exception => e
      { code: 22, message: e }.to_json
    end
  end

  def self.execute(opts)

    while(opts.any?)
      case opts.shift
      when '-p', '--port'
        set :port, opts.shift
      when '-h', '--help'
        puts "."
      else
        puts "Invalid argument, using default port 4567"
      end
    end if opts



    post "/github" do
      data = JSON.parse(request.body.read, symbolize_names: true)
      system("echo '#{JSON.pretty_generate(data)}' > /tmp/github")
    end
   
    # get "/compare/:task/:hash1/:hash2" do
    #   Manager.instance.compare(params[:hash1], params[:hash2], nil, params[:task])
    # end


  # GET
    # `bsf sources list`
    get "/sources/list" do
    end
    # `bsf sources show`
    get "/sources/show" do
    end
    # `bsf vars`
    get "/vars" do
      vars = VarManager.instance.var_list()
    end
    # `bsf tasks`
    get "/tasks" do
      get_handler do
        data = {}
        Config.instance.tasks.keys.each do |task|
          data[task] = {description: Config.instance.task_description(task)}
        end
        data
      end
    end
    # `bsf search $<opts>``
    get "/search/:opts" do
    end
    # `bsf log $<task>`
    get "/log/:task/:hash" do
      get_handler do
        contents = Manager.instance.log(params[:task], params[:hash], nil)
        { log: contents }
      end
    end
    # `bsf status`
    get "/status/:hash" do
      get_handler do
        contents = Manager.instance.status(params[:hash])
        data = []
        contents.each_line do |line|
          status, name = line.chomp.split(': ')
          data << { name: name, status: status }
        end
        json
      end
    end
    # `bsf ls <task> {commit_id}` WORKS
    get "/ls/:task" do
      data = {}
      data[:files] = Manager.instance.ls(params[:task], nil).split("\n")

      content_type :json
      data.to_json
    end
    # `bsf cat <task> <file> {commit_id}`
    get "/cat/:task/:file" do
    end
    # `bsf compare <task> $<opts>`
    get "/compare/:task/:hash1/:hash2" do
      args = ["#{params[:hash1]}:#{params[:hash2]}", "-o json"]
      content_type :json
      JSON.parse(Manager.instance.compare(params[:task], args)).to_json
    end
    # `bsf report <task> $<opts>`
    get "/report/:task/:opts" do
    end
    
  # POST
    # post "/compare" do
    #   request.body.rewind
    #   data = JSON.parse(request.body.read, symbolize_names: true)
    #   args = ["#{data[:hash1]}:#{data[:hash2]}", "-o json"]

    #   content_type :json
    #   JSON.parse(Manager.instance.compare(data[:task], args)).to_json
    # end



    # `bsf sources get ${sources}`
    post "/sources" do
      handler("Repository cloned successfully") do |data|
        Source.get_sources(data[:source], data[:single])
      end
    end
    # `bsf sources delete <sources>`
    delete "/sources" do
      handler("Repository deleted successfully") do |data|
        Source.delete_sources(data[:source])
      end
    end

    # `bsf set <var>=<value>`
    put "/vars" do
      handler("Input variable updated successfully") do |data|
        VarManager.instance.set(data[:var], data[:value])
        VarManager.instance.save
      end
    end

    put "/git" do
      handler("Git command executed successfully") do |data|
        GitManager.internal_git(opts[:gitcommand])
      end
    end

    # `bsf saveconfi <path>`
    post "/saveconfig" do
      handler("Config saved successfully") do |data|
        Config.save_config(data[:path])
      end
    end
    
    # `bsf execute ${task}`
    post "/execute" do
      handler("Execution finished") do |data|
        Manager.instance.build(data[:task], data[:y])
      end
    end
    # `bsf publish`
    post "/publish" do
      handler("Publish successful") do |data|
        Manager.instance.publish()
      end
    end
    # `bsf clean ${task}`
    post "/clean" do
    end


    # get "/compare/:task/:hash1/:hash2" do
    #   # Manager.instance.compare(params[:hash1], params[:hash2], nil, params[:task])
    #   args = ["#{params[:hash1]}:#{params[:hash2]}"]
    #   Manager.instance.compare(params[:task], args)
    # end
    # get "/compare/:task/:hash1/:hash2/:opts" do
    #   # Manager.instance.compare(params[:hash1], params[:hash2], nil, params[:task])
    #   args = ["#{params[:hash1]}:#{params[:hash2]}", params[:opts]]
    #   Manager.instance.compare(params[:task], args)
    # end


    # get "/ls/:task/:hash" do
    #   Manager.instance.ls(params["task"], params["hash"])
    # end
    # get "/cat/:task/:hash/:file" do
    #   Manager.instance.cat(params[:task], params[:hash], params[:file])
    # end
    # get "/status/:hash" do
    #   Manager.instance.status(params[:hash])
    # end
    # get "/log/:task/:hash" do
    #   Manager.instance.log(params[:task], params[:hash])
    # end
    # get "/diff/:hash1/:hash2" do
    #   Manager.instance.diff(params[:hash1], params[:hash2])
    # end
    # get "/search/:args" do
    #   GitManager.search_log(params[:args])
    # end
    run!
  end
end

