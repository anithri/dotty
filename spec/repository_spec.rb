require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Dotty::Repository do

  describe ".add_repository" do
    include_context "profile data"

    it "should add it to the repositories list" do
      suppress_output do
        Dotty::Repository.add_repository("new_repo", "git://github.com/user/repo1.git")
      end
      Dotty::Repository.repositories.size.should == 3
    end

    it "should return the new repository" do
      suppress_output do
        @repo = Dotty::Repository.add_repository("new_repo", "git://github.com/user/repo1.git")
      end
      @repo.should be_kind_of Dotty::Repository
    end

    it "should invoke Dotty::Profile.write_yaml" do
      Dotty::Profile.should_receive(:write_yaml)
      Dotty::Repository.add_repository("new_repo", "git://github.com/user/repo1.git")
    end
  end

  describe ".add_existing_repository" do
    it "should trigger .add_repository" do
      new_repo = Dotty::Repository.new('new_repo_name', 'url')
      Dotty::Repository.should_receive(:add_repository).once.with('new_repo_name', 'url').and_return(new_repo)
      suppress_output do
        @repo = Dotty::Repository.add_existing_repository('new_repo_name', 'url')
      end
    end

    it "should trigger the repository checkout action" do
      Dotty::Repository.actions.should_receive(:checkout).once.with(instance_of Dotty::Repository)
      suppress_output do
        @repo = Dotty::Repository.add_existing_repository("existing_repo", "url")
      end
    end

    it "should trigger the bootstrap repository action" do
      Dotty::Repository.actions.stub!(:bootstrap)
      Dotty::Repository.actions.should_receive(:bootstrap)
      suppress_output do
        Dotty::Repository.add_existing_repository("existing_repo", "git://github.com/user/repo1.git")
      end
    end
  end

  describe ".create_repository" do
    include_context "bootstrapped repository"

    it "should trigger the create repository action" do
      @actions.stub!(:create)
      @actions.should_receive(:create)

      suppress_output do
        Dotty::Repository.create_repository("new_repo", "git://github.com/user/repo1.git")
      end
    end

    it "should trigger .add_repository" do
      Dotty::Repository.stub!(:add_repository).and_return(Dotty::Repository.new("new_repo", "url"))
      Dotty::Repository.should_receive(:add_repository)

      suppress_output do
        Dotty::Repository.create_repository("new_repo", "git://github.com/user/repo1.git")
      end
    end
  end

  describe ".import" do
    it "should invoke .add for all repositories in the given yaml file" do
      yaml_path = Tempfile.new("dotty-test-import").path
      File.open(yaml_path, 'w') do |f|
        f.write({
          'repo1' => { 'url' => 'url1' },
          'repo2' => { 'url' => 'url2' }
        }.to_yaml)
      end
      Dotty::Repository.stub(:add_existing_repository)
      Dotty::Repository.should_receive(:add_existing_repository).once.with('repo1', 'url1')
      Dotty::Repository.should_receive(:add_existing_repository).once.with('repo2', 'url2')
      Dotty::Repository.import yaml_path
    end
  end

  describe ".list" do
    it "should return an empty array when Profile.current_profile_data is empty" do
      Dotty::Profile.stub!(:current_profile_data).and_return({})
      Dotty::Repository.list.should == []
    end

    context "with profile data" do
      include_context "profile data"

      it "should return an array with the same number of repository instances as in profile_data" do
        Dotty::Repository.list.size.should == 2
      end

      it "should return an array consisting of Dotty::Repository instances" do
        Dotty::Repository.list.collect(&:class).uniq.should == [Dotty::Repository]
      end

      it "should have objects with the correct name value" do
        Dotty::Repository.list.collect(&:name).should == %w(my_repo other_repo)
      end

      it "should have objects with the correct url" do
        Dotty::Repository.list.collect(&:url).should == %w(git://github.com/me/my_repo git://github.com/me/other_repo)
      end

      it "should return a string with the currently selected target repository" do
        Dotty::Repository.current_target.should == 'my_repo'
      end
    end
  end

  describe ".current_target=" do
    include_context "profile data"

    it "should not raise an error if set to a valid error" do
      expect {
        Dotty::Repository.current_target = "other_repo"
      }.to_not raise_error Dotty::InvalidRepositoryNameError, "Not changing current target:  no repository of that name exists"
    end
    
    it "should raise an error if set to an invalid value" do
      expect {
        Dotty::Repository.current_target = 'bad_name'
      }.to raise_error Dotty::InvalidRepositoryNameError, "Not changing current target:  no repository of that name exists"
    end
  end

  describe ".default_target" do
    include_context "profile data"
    it "should be '' if Repository.length is not 1" do
      Dotty::Repository.stub!(:current_target).and_return([])
      Dotty::Repository.default_target.should == ''
      Dotty::Repository.stub!(:current_target).and_return([Dotty::Repository.new('a','urla'),Dotty::Repository.new('b','urlb')])
      Dotty::Repository.default_target.should == ''
    end

    it "should be the name of the only entry if there is only 1 entry" do
      Dotty::Repository.stub!(:current_target).and_return([Dotty::Repository.new('a','urla')])
    end
  end

  describe ".reset_current_target" do
    include_context "profile data"
    it "should do nothing if the current .current_target is still valid" do
      Dotty::Repository.stub(:current_target=)
      Dotty::Repository.should_not_receive(:current_target=)
      suppress_output do
        Dotty::Repository.reset_current_target
      end
    end

    it "should do call .current_default if the current .current_target is not valid" do
      Dotty::Repository.stub(:current_target).and_return("bad_name")
      Dotty::Repository.stub(:current_target=)
      Dotty::Repository.should_receive(:current_target=).once
      suppress_output do
        Dotty::Repository.reset_current_target
      end
    end
  end
  
  describe ".find" do
    include_context "profile data"

    it "should return the correct repository given a name that exists" do
      repo = Dotty::Repository.find('my_repo')
      repo.name.should == 'my_repo'
      repo.url.should == 'git://github.com/me/my_repo'
    end
  end

  describe "#initialize" do
    it "should return a Dotty::Repository instance given valid attributes" do
      Dotty::Repository.new('repo1', 'git://github.com/user/repo1.git').should be_instance_of Dotty::Repository
    end

    it "should raise an error if the name is not valid" do
      expect {
        Dotty::Repository.new('repo a', 'sdfsdf')
      }.to raise_error Dotty::InvalidRepositoryNameError, "Repository name can only contain letters, numbers and the following characters: .-_"
    end
  end

  describe "#destroy" do
    include_context "bootstrapped repository"

    it "should return the instance" do
      suppress_output do
        @repo.destroy.should == @repo
      end
    end

    it "should remove the repository from the list" do
      repositories = Dotty::Repository.list
      suppress_output do
        @repo.destroy
      end
      Dotty::Repository.repositories.should == repositories - [@repo]
    end

    it "should invoke Dotty::Profile.write_yaml" do
      Dotty::Profile.should_receive(:write_yaml)
      suppress_output do
        @repo.destroy
      end
    end

    it "should invoke Dotty::RepositoryActions#destroy" do
      @actions.stub!(:destroy)
      @actions.should_receive(:destroy).with(@repo)
      suppress_output do
        @repo.destroy
      end
    end
  end

  describe "#git_status" do
    include_context "bootstrapped repository"

    before do
      @repo.stub(:git_status_output).and_return(" D gvimrc\n?? a\n")
    end

    it "should return an hash with the changes" do
      @repo.git_status.should == { 'gvimrc' => ' D', 'a' => '??' }
    end
  end

  describe "#unpushed_changes?" do
    include_context "bootstrapped repository"

    it "should return false when there are no unpushed commits" do
      @repo.unpushed_changes?.should == false
    end

    # TODO find a good way to test this
    #it "should should return true if git repo has commits that haven't been pushed" do
    #end
  end

  context "with a @repo" do
    before do
      @repo = Dotty::Repository.new('repo1', 'git://github.com/user/repo1.git')
      FileUtils.mkdir_p @repo.local_path
    end

    describe "#local_path" do
      it "should return the correct local path" do
        @repo.local_path.should == '/tmp/dotty-testing-root/default/repo1'
      end
    end

    describe "#url" do
      it "should return the correct url" do
        @repo.url.should == 'git://github.com/user/repo1.git'
      end
    end

    describe "#name" do
      it "should return the correct name" do
        @repo.name.should == 'repo1'
      end
    end

    describe "#symlinks_from_dotfiles_directories" do
      before do
        @dotfile_dirs = {
          :default => File.join(@repo.local_path, 'dotfiles'),
          :other => File.join(@repo.local_path, 'other_dotfiles')
        }
        @dotfile_dirs.each_pair do |name, path|
          FileUtils.mkdir_p(path)
        end
      end

      it "should return the correct symlinks for regular files in dotfiles/" do
        %x(touch #{@dotfile_dirs[:default]}/.a && touch #{@dotfile_dirs[:default]}/b)
        @repo.symlinks_from_dotfiles_directories.should == { 'dotfiles/.a' => '.a', 'dotfiles/b' => 'b' }
      end

      it "should handle files in the dotfiles root correctly" do
        FileUtils.mkdir(File.join @dotfile_dirs[:default], '.a')
        FileUtils.mkdir(File.join @dotfile_dirs[:default], 'b')
        @repo.symlinks_from_dotfiles_directories.should == { 'dotfiles/.a' => '.a', 'dotfiles/b' => 'b' }
      end

      it "should handle files and directories within in+XXX directories" do
        FileUtils.mkdir_p(File.join @dotfile_dirs[:default], 'in+.other_dir/b')
        %x(touch #{@dotfile_dirs[:default]}/in+.other_dir/.a)
        @repo.symlinks_from_dotfiles_directories.should == { 'dotfiles/in+.other_dir/.a' => '.other_dir/.a', 'dotfiles/in+.other_dir/b' => '.other_dir/b' }
      end

      it "should handle nested in+XXX dirs" do
        FileUtils.mkdir_p(File.join @dotfile_dirs[:default], 'in+first/in+second/a')
        %x(touch #{@dotfile_dirs[:default]}/in+first/b)
        %x(touch #{@dotfile_dirs[:default]}/in+first/in+second/c)
        @repo.symlinks_from_dotfiles_directories.should == {
          'dotfiles/in+first/in+second/a' => 'first/second/a',
          'dotfiles/in+first/b' => 'first/b',
          'dotfiles/in+first/in+second/c' => 'first/second/c'
        }
      end

      it "should not include stuff in dirs without the in+XXX convention" do
        FileUtils.mkdir_p(File.join @dotfile_dirs[:default], 'main/sub')
        @repo.symlinks_from_dotfiles_directories.should == {
          'dotfiles/main' => 'main'
        }

      end
    end

    describe "#symlinks_from_yaml" do
      it "should return an empty hash if there is no dotty-symlinks.yml file or dotfiles/* in the repo" do
        @repo.symlinks.should == {}
      end

      it "should return a hash with the correct symlinks if dotty-symlinks.yml file exists" do
        expected_symlinks = { 'a' => 'aa', 'b' => 'bb' }
        File.open File.join(@repo.local_path, 'dotty-symlinks.yml'), 'w' do |f|
          f.write expected_symlinks.to_yaml
        end
        @repo.symlinks_from_yaml.should == expected_symlinks
      end
    end

    describe "#symlinks" do
      it "should return #symlinks_from_dotfiles_directories merged with #symlinks_from_yaml" do
        @repo.stub!(:symlinks_from_dotfiles_directories).and_return({ :a => 1, :b => 2})
        @repo.stub!(:symlinks_from_yaml).and_return({ :b => 3, :c => 4})
        @repo.symlinks.should == { :a => 1, :b => 3, :c => 4 }
      end
    end

    describe "#has_thor_task?" do
      it "should return true when dotty-repository.thor is present in the repo" do
        %x{touch #{@repo.local_path}/dotty-repository.thor}
        @repo.has_thor_task?.should === true
      end

      it "should return false when there is no dotty-repository.thor present in the repo" do
        @repo.has_thor_task?.should === false
      end
    end
  end

end
