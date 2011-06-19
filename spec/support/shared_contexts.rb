shared_context "added repository" do
  before do
    @repo = Dotty::Repository.new('repo', { :url => 'git://github.com/user/repo.git' })
    Dotty::Repository.list << @repo
    FileUtils.mkdir_p @repo.local_path
    @actions = Dotty::Repository.actions
    
    %x{touch #{File.join @repo.local_path, 'temp'}}
    @symlinks = { 'a' => 'aa', 'b' => 'bb' }
    File.open File.join(@repo.local_path, 'dotty-symlinks.yml'), 'w' do |f|
      f.write @symlinks.to_yaml
    end
    %x(git init #{@repo.local_path})
  end
end

shared_context "bootstrapped repository" do
  include_context "added repository"
  before do
    @symlinks.each do |source_name, dest_name| 
      source_path = File.join @repo.local_path, source_name
      destination_path = File.join Dotty::RepositoryActions::USER_HOME, dest_name
      %x{touch #{source_path}}
      %x{ln -s #{source_path} #{destination_path}} unless File.exist?(destination_path)
    end
  end
end
      

shared_context "two in memory repositories" do
  before do
    @repo1 = Dotty::Repository.new('repo1name', 'url')
    @repo2 = Dotty::Repository.new('repo2name', 'url2')
    Dotty::Repository.repositories = [@repo1, @repo2]
  end
end

shared_context "profile data" do
  before do
    @profile_data = {
      'current_profile' => 'my_profile',
      'profiles' => {
          'my_profile' => {
            'current_target' => 'my_repo',
            'repositories' => {
              'my_repo'     => { 'url' => 'git://github.com/me/my_repo' },
              'other_repo'  => { 'url' => 'git://github.com/me/other_repo' }
            }
          },
          'other_profile' => {
            'current_target' => 'other_repo',
            'repositories' => {
              'my_repo'     => { 'url' => 'git://github.com/me/my_repo' },
              'other_repo'  => { 'url' => 'git://github.com/me/other_repo' }
            }
          }
      }
    }
    File.open(Dotty::Profile::YAML_PATH, 'w') do |f|
      f.write(@profile_data.to_yaml)
    end
  end
end
