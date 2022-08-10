module OptionParser
  
  class OptionParser
    attr_reader :opts
    def initialize(argv)
      @opts = {}
      set(argv)
    end

    def set(argv)
      tmp = argv.shift
      case tmp
      when /init/
        @opts.store(:command, :init)
        @opts.store(:file, argv.shift)
      when /build/
        @opts.store(:command, :build) 
        @opts.store(:build, argv)
      when /log/
        @opts.store(:command, :log)
        %w[-t -tail].each { |flag| @opts.store(:flag, true) if argv.include? flag }
        @opts.store(:log, argv[-1])
      when /help/ 
        @opts.store(:command, :help)
      when /var_list/
        @opts.store(:command, :var_list)
      when /set/
        @opts.store(:command, :set)
        @opts.store(:set, argv.shift)
      when /repo_list/
        @opts.store(:command, :repo_list) 
      when /status/
        @opts.store(:command, :status) 
      when /publish/
        @opts.store(:command, :publish)
      when /clone/
        @opts.store(:command, :clone)
        @opts.store(:clone, argv.shift)
      when /git/
        @opts.store(:command, :git)
        @opts.store(:git, argv.join(" "))
      when /save_config/
        @opts.store(:command, :save_config)
        @opts.store(:save_config, argv.shift)
      when /versions/
        @opts.store(:command, :versions)
        @opts.store(:versions, argv.shift)
      when /tail/
        @opts.store(:command, :tail)
        @opts.store(:tail, argv.shift)
      when /search/
        @opts.store(:command, :search)
        @opts.store(:search, argv)
      when /clean/
        @opts.store(:command, :clean)
      when /compare/
        @opts.store(:command, :compare)
        @opts.store(:json, false) 
        %w[-j -json].each { |j| @opts.store(:json, true) and argv.delete(j) if argv.include? j }
        @opts.store(:compare, argv)
      when /sources/
        @opts.store(:command, :sources)
        @opts.store(:sources, argv)
      end
    
    end
  end
end

