module Dotty
  class App < Thor
    include Thor::Actions
    include Dotty::Helpers

    ROOT_PATH = File.expand_path(File.join Thor::Util.user_home, '.dotty')
    source_root File.join(File.dirname(__FILE__), '../../templates')

    desc "list", "List installed dotty repositories"
    def list
      say "Installed dotty repositories for profile '#{Profile::current_profile}'", :blue
      say "\n"
      if Repository.list.empty?
        say "No repositories here. Use 'create', 'add' or 'import_repos' to get going.", :yellow
      else
        table = Repository.list.collect do |repo|
          git_changes = repo.git_status.size > 0 ? shell.set_color(" [#{repo.git_status.size} uncomitted changes]", :red) : ""
          git_changes += shell.set_color(" [unpushed commits]", :red) if repo.unpushed_changes?
          [repo.name, repo.url + git_changes]
        end
        print_table table, :ident => 2, :colwidth => 20
      end
      say "\n"
    end

    desc "add <name> <git repo url>", "Add existing dotty git repository"
    def add(repo_name, url)
      Repository.add_existing_repository repo_name, url
    end

    desc "create <name> <git repo url>", "Create a new git repository with the specified git repo url as origin"
    def create(repo_name, repo_url)
      repo = Dotty::Repository.create_repository(repo_name, repo_url)
      empty_directory File.join(repo.local_path, 'dotfiles')
      copy_file "README.md", File.join(repo.local_path, 'README.md')
    end

    desc "remove <name>", "Remove dotty repository"
    def remove(repo_name)
      find_repo!(repo_name).destroy
    end

    desc "update [name]", "Update specified or all dotty repositories"
    def update(repo_name=nil)
      for_specified_or_all_repos(repo_name) do |repo|
        actions.update repo
      end
    end

    desc "bootstrap [name]", "Bootstrap specified or all dotty repositories. Usually involves making symlinks in your home dir."
    def bootstrap(repo_name=nil)
      for_specified_or_all_repos(repo_name) do |repo|
        actions.bootstrap repo
      end
    end

    desc "implode [name]", "Opposite of bootstrap"
    def implode(repo_name=nil)
      for_specified_or_all_repos(repo_name) do |repo|
        actions.implode repo
      end
    end

    desc "update_submodules [name]", "For specified or all repositories,  for submodules and pull"
    method_options :push => false
    method_options :commit => true
    method_options :ignoredirty => false
    def update_submodules(repo_name=nil)
      for_specified_or_all_repos(repo_name) do |repo|
        actions.invoke :update_submodules, [repo], options
      end
    end

    desc "execute [repo name] <command to run>", "For specified or all repositories, run given command"
    def execute(repo_name=nil, command)
      for_specified_or_all_repos(repo_name) do |repo|
        inside repo.local_path do
          run command
          say "\n"
        end
      end
    end

    desc "import_repos <yaml_file_location>", "Imports dotty repositories from the specified yaml file location (http works)"
    def import_repos(location)
      say_status "import yaml", "Importing dotty repositories from '#{location}'", :blue
      Repository.import location
    end

    desc "profile [profile name]", "Switch to given profile or show current profile if no profile name is given"
    def profile(name=nil)
      if name.nil?
        say "Current dotty profile: " + shell.set_color(Profile.current_profile, :blue)
      else
        name = name.downcase
        Profile.find!(name)
        say_status "profile", "Changing to profile '#{name}'"
        implode # Implode all repos for current profile
        Repository.repositories = nil # Force reload of repositories
        Profile.current_profile = name
        Profile.write_yaml
        bootstrap # Bootstrap repos for the profile we changed to
      end
    end

    desc "profiles", "List profiles"
    def profiles
      say "DOTTY PROFILES\n", :blue
      profile_names = Profile.profiles
      profile_names << 'default' if profile_names.empty?
      profile_names.each do |profile_name|
        with_padding do
          say Profile.current_profile == profile_name ? shell.set_color('* ' + profile_name, :green) : profile_name
        end
      end
    end

    desc "create_profile <profile name>", "Create a new profile"
    def create_profile(name)
      say_status "create", "Create profile '#{name}'"
      Profile.create name
    end

    desc "remove_profile <profile name>", "Remove given profile"
    def remove_profile(name)
      say_status "remove", "Removing profile '#{name}'"
      Profile.remove name
    end

    protected

    def find_repo!(name)
      Repository.find(name.downcase) || raise(RepositoryNotFoundError, "The specified repository does not exist")  
    end

    def actions
      @actions ||= RepositoryActions.new
    end

    def for_specified_or_all_repos(repo_name=nil)
      if repo_name
        yield find_repo!(repo_name.downcase)
      else
        Repository.list.each { |repo| yield repo }
      end
    end


  end
end
