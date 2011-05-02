require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Dotty::RepositoryActions do

  describe "#create" do
    before do
      @repo = Dotty::Repository.new('repo', 'git://github.com/user/repo.git')
      suppress_output do
        subject.create @repo
      end
    end

    it "should initialize an empty git repository" do
      Dir.exist?(File.join @repo.local_path, '.git').should be_true
    end

    it "should create a git remote called origin with the specified url" do
      output = nil
      suppress_output do
        output = `cd #{@repo.local_path}; git remote -v`
      end
      output.should == "origin\tgit://github.com/user/repo.git (fetch)\norigin\tgit://github.com/user/repo.git (push)\n"
    end
  end

  describe "#checkout" do
    it "should check out the git repository" do
      @repo = Dotty::Repository.new('repo', 'url')
      subject.stub!(:run)
      subject.should_receive(:run).once.with('git clone url /tmp/dotty-testing-root/default/repo')
      suppress_output do
        subject.checkout @repo
      end
    end

    it "should update the fetch the repository submodules" do
      @repo = Dotty::Repository.new('repo', 'url')
      subject.stub!(:run)
      subject.should_receive(:run).once.with('git submodule update --init')
      suppress_output do
        subject.checkout @repo
      end
    end
  end

  describe "#destroy" do
    include_context "bootstrapped repository"

    it "should remove the local repository directory" do
      suppress_output do
        @actions.invoke :destroy, [@repo]
      end
      Dir.exist?(@repo.local_path).should be_false
    end

    it "should invoke #implode" do
      @actions.stub!(:implode)
      @actions.should_receive(:implode).with(@repo)
      suppress_output do
        @actions.destroy @repo
      end
    end
  end

  describe "#implode" do
    include_context "bootstrapped repository"

    it "should remove symlinks defined in dotty-symlinks.yml" do
      suppress_output do
        @actions.implode(@repo)
      end
      File.symlink?(File.join Dotty::RepositoryActions::USER_HOME, 'aa').should be_false
      File.symlink?(File.join Dotty::RepositoryActions::USER_HOME, 'bb').should be_false
    end

    it "should try to run repository specific implode action if dotty-repository.thor exists" do
      %x(touch #{@repo.local_path}/dotty-repository.thor)
      @actions.stub!(:run)
      @actions.should_receive(:run).once.with('thor dotty_repository:implode')
      suppress_output do
        @actions.implode(@repo)
      end
    end

    it "should not try to run a repository specific implode action if dotty-repository.thor does not exist" do
      @actions.stub!(:run)
      @actions.should_not_receive(:run).with('thor dotty_repository:implode')
      suppress_output do
        @actions.implode(@repo)
      end
    end
    
  end

  describe "#bootstrap" do
    include_context "added repository"

    it "should create symlinks returned from repository#symlinks" do
      @repo.stub!(:symlinks).and_return({ 'a' => '.a', 'b' => '.b' })
      suppress_output do
        @actions.bootstrap(@repo)
      end
      File.symlink?(File.join Dotty::RepositoryActions::USER_HOME, '.b').should be_true
      File.symlink?(File.join Dotty::RepositoryActions::USER_HOME, '.a').should be_true
    end

    it "should make directories for the symlinks if needed" do
      @repo.stub!(:symlinks).and_return({ 'b' => 'other/dir/b' })
      suppress_output do
        @actions.bootstrap(@repo)
      end
      File.directory?(File.join Dotty::RepositoryActions::USER_HOME, 'other/dir').should be_true
      File.symlink?(File.join Dotty::RepositoryActions::USER_HOME, 'other/dir/b').should be_true
    end

    it "should try to run repository specific bootstrap action if dotty-repository.thor exists" do
      %x(touch #{@repo.local_path}/dotty-repository.thor)
      @actions.stub!(:run)
      @actions.should_receive(:run).once.with('thor dotty_repository:bootstrap')
      suppress_output do
        @actions.bootstrap(@repo)
      end
    end

    it "should not try to run a repository specific bootstrap action if dotty-repository.thor does not exist" do
      @actions.stub!(:run)
      @actions.should_not_receive(:run).with('thor dotty_repository:bootstrap')
      suppress_output do
        @actions.bootstrap(@repo)
      end
    end
  end

  describe "#update" do
    include_context "bootstrapped repository"
    
    it "should run git commands to update repo" do
      @actions.stub!(:run)
      @actions.should_receive(:run).once.with('git fetch && git pull && git submodule update --init')
      suppress_output do 
        @actions.update @repo
      end
    end
  end

  describe "#update_submodules" do
    include_context "bootstrapped repository"
    
    before do
      # TODO: Find a better way of testing thor invocations with options
      @default_method_options = { :commit => true, :commit_message => 'Updated submodules' }
      @actions.stub!(:options).and_return(@default_method_options)
      @actions.stub!(:run).and_return("")
    end
    
    it "should by default update pull submodules and commit changes to the dotty repository" do
      @actions.should_receive(:run).once.with("git submodule update --init && git submodule foreach git pull origin master && git commit -am 'Updated submodules'")
      suppress_output do 
        @actions.update_submodules @repo
      end
    end

    it "should not commit if commit option is false" do
      @actions.stub!(:options).and_return @default_method_options.merge(:commit => false)
      @actions.should_receive(:run).once.with('git submodule update --init && git submodule foreach git pull origin master')
      suppress_output do
        @actions.update_submodules @repo
      end
    end

    it "should push if push option is true" do
      @actions.stub!(:options).and_return @default_method_options.merge(:push => true)
      @actions.should_receive(:run).once.with(/git push/)
      suppress_output do
        @actions.update_submodules @repo
      end
    end

    it "should raise error if the repository is not in a clean state" do
      @actions.stub!(:run).and_return("?? dirty")
      expect {
        suppress_output { @actions.update_submodules @repo }
      }.to raise_error Dotty::Error, "Repository 'repo' is not in a clean state - cannot commit updated submodules"
    end

    it "should not raise error if the repository is not in a clean state but --no-commit is supplied" do
      @actions.stub!(:run).and_return("?? dirty")
      expect {
        suppress_output { @actions.invoke :update_submodules, [@repo], :commit => false }
      }.to_not raise_error Dotty::Error, "Repository 'repo' is not in a clean state - cannot commit updated submodules"
    end

    it "should not raise an error when repository is not in clean state but --ignore_dirty is given" do
      @actions.stub!(:run).and_return("?? dirty")
      @actions.stub!(:options).and_return @default_method_options.merge(:ignoredirty => true)
      expect {
        suppress_output { @actions.update_submodules @repo }
      }.to_not raise_error Dotty::Error, "Repository 'repo' is not in a clean state - cannot commit updated submodules"
    end
      
  end

end

