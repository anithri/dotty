require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Dotty::Profile do
  
  describe ".create" do
    it "should add the profile to profile_data" do
      Dotty::Profile.create 'name'
      Dotty::Profile.profile_data['profiles'].should have_key 'name'
    end

    it "should invoke .write_yaml" do
      Dotty::Profile.stub!(:write_yaml)
      Dotty::Profile.should_receive(:write_yaml)
      Dotty::Profile.create 'name'
    end
  end

  describe ".remove" do
    include_context "profile data"

    it "should remove the profile from profile_data" do
      Dotty::Profile.remove 'my_profile'
      Dotty::Profile.profile_data['profiles'].should_not have_key 'my_profile'
    end

    it "should invoke .write_yaml" do
      Dotty::Profile.should_receive(:write_yaml)
      Dotty::Profile.remove 'my_profile'
    end

    it "should set current_profile to the first existing profile" do
      Dotty::Profile.current_profile = 'my_profile'
      Dotty::Profile.remove 'my_profile'
      Dotty::Profile.current_profile.should == 'other_profile'
    end
  end

  describe ".profile_data" do
    it "should return data by calling .read_yaml the first time" do
      Dotty::Profile.should_receive(:read_yaml).once.and_return(:test)
      Dotty::Profile.profile_data.should == :test
    end

    it "should use cached data when available" do
      Dotty::Profile.stub!(:read_yaml).and_return(:test)
      Dotty::Profile.profile_data # cache data
      Dotty::Profile.should_not_receive(:read_yaml)
      Dotty::Profile.profile_data.should == :test
    end
  end

  describe ".current_profile" do
    it "should return 'default' if no data is set and there are no profiles" do
      Dotty::Profile.instance_variable_set '@profile_data', {}
      Dotty::Profile.current_profile.should == 'default'
    end

    it "should use the value from @profile_data if its set and @current_profile isnt" do
      Dotty::Profile.instance_variable_set('@profile_data', { 'current_profile' => 'myprofile' })
      Dotty::Profile.current_profile.should == 'myprofile'
    end

    it "should use @current_profile when its set" do
      Dotty::Profile.instance_variable_set('@profile_data', { 'current_profile' => 'myprofile' })
      Dotty::Profile.instance_variable_set('@current_profile', 'banana')
      Dotty::Profile.current_profile.should == 'banana'
    end

    context "with profiles" do
      include_context "profile data"
      it "should use the first repo when profile_data does not have a current_profile set" do
        Dotty::Profile.profile_data['current_profile'] = nil
        Dotty::Profile.current_profile.should == 'my_profile'
      end
    end
  end

  describe ".current_profile_data" do
    include_context "profile data"

    it "should return the profile's section in profile_data" do
      Dotty::Profile.stub!(:profile_data).and_return(@profile_data)
      Dotty::Profile.current_profile_data.should == {
        'current_target' => 'my_repo',
        'repositories' => {
          'my_repo' => {
            'url' => 'git://github.com/me/my_repo'
          },
          'other_repo' => {
            'url' => 'git://github.com/me/other_repo'
          }
        }
      }
    end

    it "should return empty hash when there is no profile data" do
      FileUtils.rm Dotty::Profile::YAML_PATH
      Dotty::Profile.current_profile_data.should == {}
    end
  end

  describe ".read_yaml" do
    include_context "profile data"

    it "should return the data structure defined in the yaml" do
      Dotty::Profile.read_yaml.should == @profile_data
    end

    it "should return false if there is no ~/.dotty/.profiles.yml" do
      FileUtils.rm Dotty::Profile::YAML_PATH
      Dotty::Profile.read_yaml.should == false
    end

  end

  describe ".write_yaml" do
    include_context "profile data"

    it "should create the file when it doesnt exist" do
      FileUtils.rm Dotty::Profile::YAML_PATH
      Dotty::Profile.write_yaml
      File.exist?(Dotty::Profile::YAML_PATH).should be_true
    end

    it "should write data so that .read_yaml returns identical data" do
      Dotty::Profile.instance_variable_set '@profile_data', @profile_data
      Dotty::Profile.write_yaml
      Dotty::Profile.read_yaml.should == @profile_data
    end

    it "should write updated repository data" do
      repo = Dotty::Repository.list.first
      repo.name = 'newreponame'
      Dotty::Profile.write_yaml
      Dotty::Profile.read_yaml.should == {
        "current_profile" => "my_profile", 
        "profiles" => {
          "my_profile" => {
            "current_target" => "my_repo",
            "repositories" =>{
              "newreponame" => { "url"=>"git://github.com/me/my_repo" }, 
              "other_repo"  => { "url"=>"git://github.com/me/other_repo" }
            }
          }, 
          "other_profile" => {
            "current_target" => "other_repo",
            "repositories" => {
              "my_repo"    => { "url"=>"git://github.com/me/my_repo" }, 
              "other_repo" => { "url"=>"git://github.com/me/other_repo"}
            }
          }
        }
      }
    end
  end

  describe ".find" do
    include_context "profile data"
    it "should raise an error if the given profile name does not exist" do
      expect {
        Dotty::Profile.find! 'non_existant_profile'
      }.to raise_error(Dotty::Error, "Profile 'non_existant_profile' does not exist")
    end

    it "should return the profile data if the profile exists" do
      Dotty::Profile.find!('other_profile').should == {
        'current_target' => 'other_repo',
        'repositories' => {
          'my_repo'     => { 'url' => 'git://github.com/me/my_repo' },
          'other_repo'  => { 'url' => 'git://github.com/me/other_repo' }
        }
      }
    end
  end

  #describe "#new" do
    #it "should return an instance of Dotty::Profile" do
      #profile = Dotty::Profile.new('name')
      #profile.should be_instance_of Dotty::Profile
    #end
  #end

  #describe "#name" do
    #it "should return the given name" do
      #profile = Dotty::Profile.new('name')
      #profile.name.should == 'name'
    #end
  #end

end


