module Dotty
  class RepositoryActions < Thor
    USER_HOME = Thor::Util.user_home

    include Thor::Actions
    include Dotty::Helpers
 
    desc "create <repo instance>", "create repository"
    def create(repo)
      say_status "create repo", "#{repo.name} [#{repo.url}]", :blue
      FileUtils.mkdir_p repo.local_path
      run "git init #{repo.local_path}"
      inside repo.local_path do
        run "git remote add origin #{repo.url}"
      end
    end

    desc "destroy <repo instance>", "remove repository"
    def destroy(repo)
      say_status "remove repo", repo.name, :blue
      implode repo
      say_status "remove", repo.local_path
      FileUtils.rm_rf repo.local_path
    end

    desc "checkout <repo instance>", "add repository"
    def checkout(repo)
      say_status "add repo", "#{repo.name} => #{repo.url}", :blue
      FileUtils.mkdir_p repo.local_path
      run "git clone #{repo.url} #{repo.local_path}"
      inside repo.local_path do
        run "git submodule update --init"
      end
    end

    desc "bootstrap <repo instance>", "bootstrap repository"
    def bootstrap(repo)
      say_status "bootstrap", repo.name, :blue
      with_padding do
        # Create symlinks defined in dotty-symlinks.yml
        repo.symlinks.each do |source, destination_filename|
          create_link File.join(USER_HOME, destination_filename), File.join(repo.local_path, source)
        end

        # Execute repository's bootstrap task
        thor_file_path = File.join(repo.local_path, 'dotty-repository.thor')
        if File.exist? thor_file_path
          inside repo.local_path do
            run "thor dotty_repository:bootstrap"
          end
        end
      end
    end

    desc "implode <repo instance>", "implode repository"
    def implode(repo)
      say_status "implode", repo.name, :blue

      # Remove symlinks defined in dotty-symlinks.yml
      repo.symlinks.each do |source, destination_filename|
        destination_path = File.join(USER_HOME, destination_filename)
        remove_symlink destination_path
      end

      # Execute repository's implode task
      thor_file_path = File.join(repo.local_path, 'dotty-repository.thor')
      if File.exist? thor_file_path
        inside repo.local_path do
          run "thor dotty_repository:implode"
        end
      end
    end

    desc "update <repo instance>", "update repository"
    def update(repo)
      say_status "update", repo.name, :blue

      inside repo.local_path do
        run "git fetch && git pull && git submodule update --init"
      end
    end

    desc "update_submodules", "update repository's submodules"
    method_options :ignoredirty => false
    method_options %w(commit_message -m) => "Updated submodules"
    method_options :commit => true
    method_options :push => true
    def update_submodules(repo)
      say "update submodules", repo.name, :blue
      inside repo.local_path do
        cmd = []
        cmd << "git submodule update --init"
        cmd << "git submodule foreach git pull origin master"
        if options[:commit]
          changes = run('git status -s', :capture => true)
          if options[:ignoredirty] or [nil, ""].include?(changes)
            cmd << "git commit -am '#{options[:commit_message]}'"
          else
            raise Dotty::Error, "Repository '#{repo.name}' is not in a clean state - cannot commit updated submodules"
          end
          options[:push] && cmd << "git push"
        end
        run cmd.join(" && ")
      end
    end
    
    
  end
end
