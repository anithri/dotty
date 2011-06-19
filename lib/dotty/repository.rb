module Dotty
  class Repository
    YAML_PATH = File.join(App::ROOT_PATH, '.repos.yml')

    attr_accessor :name, :url

    class << self
      attr_accessor :repositories

      def add_existing_repository(name, url)
        repo = add_repository(name, url)
        actions.checkout(repo)
        actions.bootstrap(repo)
        return repo
      end

      def add_repository(name, url)
        unless Repository.find(name).nil?
          raise Dotty::Error, "There is already a repository with that name"
        end
        repo = self.new(name, url)
        list << repo
        Profile::write_yaml
        reset_current_target
        return repo
      end

      def create_repository(name, url)
        repo = add_repository(name, url)
        actions.create(repo)
        return repo
      end

      def list
        @repositories ||= (Profile.current_profile_data['repositories'] || {}).collect{ |name, options| Repository.new(name, options['url']) }
      end

      def find(name)
        list.detect{ |repo| repo.name == name }
      end

      def actions
        @actions ||= Dotty::RepositoryActions.new
      end

      def current_target
        Profile.current_profile_data['current_target'] || default_target || ''
      end

      def current_target=(val)
        unless val.empty?  || list.detect{|repo| repo.name == val}
          raise InvalidRepositoryNameError, "Not changing current target:  no repository of that name exists"
        end
        Profile.current_profile_data['current_target'] = val
        Profile::write_yaml
      end

      def current_target_repo
        raise Dotty::Error.new("No repo selected. please set current_target") if current_target == ''
        find(current_target)
      end

      def default_target
        list.length == 1 ? list[0].name : ''
      end

      def reset_current_target
        unless  Repository.find(Repository.current_target)
          Repository.current_target= default_target
        end
      end

      def import(location)
        repositories = YAML::load(open(location).read) || {}
        if repositories.empty?
          error "Didn't find any repositories at '#{location}'"
        end
        repositories.keys.each do |name|
          if find(name)
            puts "Not adding '#{name}', a repository with that name already exists"
            next
          end
          add_existing_repository(name, repositories[name]['url'])
        end
      end

    end
  
    def initialize(name, url)
      unless name =~ /^[a-zA-Z0-9\.\-\_]+$/
        raise InvalidRepositoryNameError, "Repository name can only contain letters, numbers and the following characters: .-_"
      end
      @name = name
      @url = url
    end

    def local_path
      File.join(Dotty::App::ROOT_PATH, Profile::current_profile, @name)
    end

    def symlinks
      symlinks_from_dotfiles_directories.merge symlinks_from_yaml
    end

    def symlinks_from_yaml
      symlink_file_path = File.join(local_path, 'dotty-symlinks.yml')
      File.exist?(symlink_file_path) && YAML::load(File.open symlink_file_path) or {}
    end

    def symlinks_from_dotfiles_directories
      hsh = {}
      Dir.glob(File.join local_path, '*dotfiles/') do |dotfiles_directory|
        dotfiles_directory = Pathname.new(dotfiles_directory)

        # 'root' files 
        dotfiles_directory.children.each do |path|
          next if path.basename.to_s =~ /^in\+/
          source = path.relative_path_from(Pathname.new local_path).to_s
          target = path.relative_path_from(dotfiles_directory).to_s
          hsh.merge!(source => target)
        end

        # stuff in in+XXX directories
        Dir.glob(File.join(dotfiles_directory.to_s , 'in+*/**/*'), File::FNM_DOTMATCH).each do |path|
          next if path =~ %r([\.]{2}) or path =~ %r(/\.$) # Remove BS entries like dotfiles/../otherstuff TODO: do it in a better way
          path = Pathname.new(path)
          next if path.basename.to_s =~ /^in\+/ # We dont want to do anything with the 'placeholder' directories
          source = path.relative_path_from(Pathname.new local_path).to_s
          target = path.relative_path_from(Pathname.new dotfiles_directory).to_s.gsub('in+', '')
          hsh.merge!(source => target)
        end
      end
      return hsh
    end

    def git_status
      # TODO use --json when more people have a git that supports it
      git_status_output.split("\n").inject({}) do |hsh, line|
        change_type, file = line[0..1], line[3..-1]
        hsh.merge(file => change_type)
      end
    end

    def unpushed_changes?
      txt = 'Your branch is ahead of'
      `cd #{local_path} && git status | grep '#{txt}' 2>&1`.include?(txt)
    end

    def git_status_output
      `cd #{local_path} && git status --porcelain`
    end

    def has_thor_task?
      File.exist? File.join(local_path, 'dotty-repository.thor')
    end

    def can_write_to_repo?
      Pathname(local_path).writable?
    end
    
    def invoke_action(action, *args)
      self.class.actions.invoke action, args
    end

    def destroy
      Repository.repositories.reject! { |repo| repo.name == name }
      Dotty::Profile.write_yaml
      Repository.actions.destroy self
      self
    end

    #desc "track_file <filename> <repo>", "add file to repository"
    def track_file(filename)
      raise Dotty::Error.new("repo directory does not exist or is not writable: #{name} at #{local_path}") unless can_write_to_repo?
      file = Pathname(filename)
      if file.relative?
        relative_file = file
        file = Pathname(RepositoryActions::USER_HOME) + file
      else
        raise Dotty::Error.new("file must be in your home dir") unless file.to_s.start_with?(RepositoryActions::USER_HOME)
        relative_file = file.relative_path_from(Thor::Util.user_home)
      end
      raise Dotty::Error.new("file must exist and be a file: #{relative_file} at #{local_path}") unless file.file?

      copy_and_link(file, destination_path(relative_file))
    end

    def destination_path(filename)
      final = Pathname(local_path) + 'dotfiles'
      filename.dirname.each_filename do |part|
        next if part == "."
        final += "in+" + part
      end
      final + filename.basename
    end

    def copy_and_link(src,dest)
      dest.dirname.mkpath
      src.rename(dest)
      src.make_symlink(dest)
    end
  end
end
