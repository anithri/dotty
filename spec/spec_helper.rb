$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require 'simplecov'
SimpleCov.start

require 'dotty'
require 'support/shared_contexts'
require 'tempfile'

Dotty::App.send(:remove_const, :ROOT_PATH)
Dotty::App.const_set :ROOT_PATH, '/tmp/dotty-testing-root'

Dotty::Profile.send(:remove_const, :YAML_PATH)
Dotty::Profile.const_set :YAML_PATH, Tempfile.new('dotty-profiles-test').path

Dotty::RepositoryActions.send(:remove_const, :USER_HOME)
Dotty::RepositoryActions.const_set :USER_HOME, '/tmp/dotty-testing-user-home'

RSpec.configure do |config|
  config.before(:each) do
  end

  config.after(:each) do
    clean_dotty
  end

  def clean_dotty
    [Dotty::RepositoryActions::USER_HOME, Dotty::App::ROOT_PATH].each do |p|
      system "rm -rf #{p}" if File.exist?(p)
      FileUtils.mkdir_p p
    end
    system "rm #{Dotty::Profile::YAML_PATH}" if File.exist?(Dotty::Profile::YAML_PATH)
    Dotty::Profile.profile_data = nil
    Dotty::Profile.current_profile = nil
    Dotty::Repository.repositories = nil
  end

  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end
    result
  end

  def suppress_output
    begin
      orig_stderr = $stderr.clone
      orig_stdout = $stdout.clone
      $stdout.reopen("/dev/null", "w")
      $stderr.reopen("/dev/null", "w")
      yield
    ensure
      $stdout.reopen(orig_stdout)
      $stderr.reopen(orig_stderr)
    end
  end
end
