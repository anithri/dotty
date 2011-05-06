require File.expand_path(File.dirname(__FILE__) + '/spec_helper')


describe Dotty::App do
  describe "#add" do
    it "should invoke Dotty::Repository.add" do
      name = 'repo'
      url = 'url'
      Dotty::Repository.stub!(:add_existing_repository)
      Dotty::Repository.should_receive(:add_existing_repository).with(name, url)
      subject.add(name, url)
    end
  end

  describe "#create" do
    it "should invoke Dotty::Repository.create" do
      Dotty::Repository.stub!(:create_repository).and_return(Dotty::Repository.new('name', 'url'))
      Dotty::Repository.should_receive(:create_repository).with('name', 'url')
      suppress_output do
        subject.invoke :create, %w(name url)
      end
    end

    it "should copy the README.md to the repo dir" do
      suppress_output do
        subject.invoke :create, %w(name url)
      end
      File.file?(File.join Dotty::Repository.list.first.local_path, 'README.md').should be_true
    end

    it "should create a dotfiles/ directory" do
      suppress_output do
        subject.invoke :create, %w(name url)
      end
      File.directory?(File.join Dotty::Repository.list.first.local_path, 'dotfiles').should be_true
    end

  end

  describe "#remove" do
    it "should invoke #destroy on the Repository instance with the given name" do
      repo = Dotty::Repository.new('name', 'url')
      repo.stub!(:destroy)
      repo.should_receive(:destroy)
      Dotty::Repository.repositories = [repo]
      suppress_output do
        subject.invoke :remove, %w(name)
      end
    end
  end

  describe "#update" do
    include_context "two in memory repositories"

    before do
      subject.send(:actions).stub!(:update)
    end

    it "should invoke update action with the specified repo" do
      subject.send(:actions).should_receive(:update).with(@repo1).once
      suppress_output do
        subject.update 'repo1name'
      end
    end

    it "should invoke update action for all repos if no repo is specified" do
      subject.send(:actions).should_receive(:update).with(@repo1).once
      subject.send(:actions).should_receive(:update).with(@repo2).once
      suppress_output do
        subject.update
      end
    end
  end

  describe "#bootstrap" do
    include_context "two in memory repositories"

    before do
      subject.send(:actions).stub!(:bootstrap)
    end

    it "should invoke bootstrap action with the specified repo" do
      subject.send(:actions).should_receive(:bootstrap).with(@repo1).once
      suppress_output do
        subject.bootstrap 'repo1name'
      end
    end

    it "should invoke bootstrap action for all repos if no repo is specified" do
      subject.send(:actions).should_receive(:bootstrap).with(@repo1).once
      subject.send(:actions).should_receive(:bootstrap).with(@repo2).once
      suppress_output do
        subject.bootstrap
      end
    end
  end

  describe "#implode" do
    include_context "two in memory repositories"

    before do
      subject.send(:actions).stub!(:implode)
    end

    it "should invoke implode action with the specified repo" do
      subject.send(:actions).should_receive(:implode).with(@repo1).once
      suppress_output do
        subject.implode 'repo1name'
      end
    end

    it "should invoke implode action for all repos if no repo is specified" do
      subject.send(:actions).should_receive(:implode).with(@repo1).once
      subject.send(:actions).should_receive(:implode).with(@repo2).once
      suppress_output do
        subject.implode
      end
    end
  end

  describe "#update_submodules" do
    # TODO add these when I figure out how to make multiple should_receive + thor work
  end

  describe "#execute" do
    include_context "two in memory repositories"

    it "should run the given command inside the the specified repository's directory" do
      subject.stub(:run) do
        subject.destination_root.should == @repo1.local_path
      end
      subject.should_receive(:run).once.with('ls')
      suppress_output do
        subject.execute 'ls', @repo1.name
      end
    end

    it "should run the given command in each repositories directroy if no repository is specified" do
      paths = [@repo1.local_path, @repo2.local_path]
      i = 0
      subject.stub(:run) do
        subject.destination_root.should == paths[i]
        i += 1
      end
      subject.should_receive(:run).twice.with('ls')
      suppress_output do
        subject.execute 'ls'
      end
    end
  end

  describe "#import_repos" do
    it "should invoke Dotty::Repository.import" do
      Dotty::Repository.stub!(:import)
      Dotty::Repository.should_receive(:import).with('location')
      suppress_output do
        subject.import_repos('location')
      end
    end
  end

  describe "#find_repo!" do
    include_context "two in memory repositories"

    it "should return the correct repo instance if it exists" do
      subject.send(:find_repo!, 'repo1name').should == @repo1 
    end

    it "should raise an exception when the given repository does not exist" do
      expect {
        subject.send(:find_repo!, 'nonexistant')
      }.to raise_error Dotty::RepositoryNotFoundError, "Repository 'nonexistant' does not exist"
    end
  end

  describe "#actions" do
    it "should return an instance of Dotty::RepositoryActions" do
      subject.send(:actions).should be_kind_of Dotty::RepositoryActions
    end

    it "should cache it" do
      app = subject
      app.send(:actions).should == app.send(:actions)
    end
  end

  describe "#for_specified_or_all_repos" do
    include_context "two in memory repositories"

    it "should yield the two registered repos" do
      subject.should_receive(:for_specified_or_all_repos).and_yield(Dotty::Repository.list)
      subject.send(:for_specified_or_all_repos) { |r| }
    end
  end

  describe "#create_profile" do
    it "should invoke Profile.create" do
      Dotty::Profile.stub(:create)
      Dotty::Profile.should_receive(:create).once.with('name')
      suppress_output do
        subject.create_profile 'name'
      end
    end
  end

  describe "#remove_profile" do
    it "should invoke Profile.remove" do
      Dotty::Profile.stub(:remove)
      Dotty::Profile.should_receive(:remove).once.with('my_repo')
      suppress_output do
        subject.remove_profile 'my_repo'
      end
    end
  end

  describe "#profiles" do
    include_context "profile data"
    it "should list existing proiles" do
      output = capture :stdout do
        subject.invoke :profiles
      end
      output.should == "\e[34mDOTTY PROFILES\n\e[0m\n  \e[32m* my_profile\e[0m\n  other_profile\n"
    end
  end

  describe "#profile" do
    include_context "profile data"

    it "should print the current profile if no profile name is given" do
      output = capture :stdout do
        subject.invoke :profile
      end
      output.gsub!(/\e\[\d+\w/, '') # Remove colors and shit
      output.should == "Current dotty profile: my_profile\n"
    end

    it "should change Profile.current_profile when given a valid profile name" do
      suppress_output do
        subject.invoke :profile, %w(other_profile)
      end
      Dotty::Profile.current_profile.should == 'other_profile'
    end

    it "should invoke Profile.write_yaml" do
      Dotty::Profile.should_receive(:write_yaml)
      suppress_output do
        subject.invoke :profile, %w(other_profile)
      end
    end

    it "should call Profile.find!" do
      Dotty::Profile.should_receive(:find!).with('other_profile')
      suppress_output do
        subject.invoke :profile, %w(other_profile)
      end
    end

    it "should invoke implode then bootstrap" do
      subject.should_receive(:implode).once.ordered
      subject.should_receive(:bootstrap).once.ordered
      suppress_output do
        subject.profile 'other_profile'
      end
    end

  end

  describe "#list" do

    context "with some repositories" do
      include_context "profile data"

      before do
        Dotty::Repository.list.each do |repo|
          %x(git init #{repo.local_path})
        end
      end

      it "should display a list of repositories" do
        output = capture(:stdout) do
          subject.list
        end
        output.gsub!(/\e\[\d+\w/, '') # Remove colors and shit
        output.should == <<-EXPECTED_OUTPUT
Installed dotty repositories for profile 'my_profile'

  my_repo               git://github.com/me/my_repo
  other_repo            git://github.com/me/other_repo

EXPECTED_OUTPUT
      end

      it "should display git changes" do
        %x(cd #{Dotty::Repository.list.first.local_path} && touch newfile)
        Dotty::Repository.list.first.stub!(:unpushed_changes?).and_return(true)
        output = capture(:stdout) do
          subject.list
        end
        output.gsub!(/\e\[\d+\w/, '') # Remove colors and shit
        output.should == <<-EXPECTED_OUTPUT
Installed dotty repositories for profile 'my_profile'

  my_repo               git://github.com/me/my_repo [1 uncomitted changes] [unpushed commits]
  other_repo            git://github.com/me/other_repo

EXPECTED_OUTPUT
      end

    end

    it "should display a message if there are no repositories" do
      Dotty::Repository.repositories = []
      output = capture(:stdout) do
        subject.list
      end
      output.gsub!(/\e\[\d+\w/, '') # Remove colors and shit
      output.should == <<-EXPECTED_OUTPUT
Installed dotty repositories for profile 'default'

No repositories here. Use 'create', 'add' or 'import_repos' to get going.

EXPECTED_OUTPUT

    end

  end

end
