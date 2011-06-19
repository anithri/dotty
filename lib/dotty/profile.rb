module Dotty
  class Profile
    YAML_PATH = File.join(App::ROOT_PATH, '.profiles.yml')

    class << self
      attr_accessor :current_profile, :profile_data

      def create(name)
        profile_data['profiles'].merge!(name => {})
        write_yaml
      end

      def remove(name)
        find!(name)
        @current_profile = profile_data['current_profile'] = nil
        profile_data['profiles'].delete name
        write_yaml
      end

      def profile_data
        @profile_data ||= read_yaml || { 'profiles' => {} }
      end

      def current_profile
        @current_profile ||= profile_data['current_profile'] || profiles.first || 'default'
      end

      def profiles
        profile_data['profiles'] && profile_data['profiles'].keys or []
      end

      def current_profile_data
        profile_data['profiles'][current_profile] or {}
      end

      def read_yaml
        File.exist?(YAML_PATH) && YAML::load(File.open YAML_PATH)
      end

      def write_yaml
        profile_data['current_profile'] = current_profile
        (profile_data['profiles'][current_profile] ||= {}).merge!(
          'current_target' => Repository.current_target,
          'repositories' => Repository.list.inject({}) { |hsh, repo| hsh.merge(repo.name => { 'url' => repo.url }) }
        )
        FileUtils.mkdir_p App::ROOT_PATH unless File.directory?(App::ROOT_PATH)
        File.open(YAML_PATH, 'w') do |f|
          f.write profile_data.to_yaml
        end
      end

      def find!(name)
        profile_data['profiles'] && profile_data['profiles'][name] or raise Dotty::Error, "Profile '#{name}' does not exist"
      end
    end

  end
end
