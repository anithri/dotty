module Dotty
  module Helpers
    def error(message, halt=true)
      exit if halt
    end

    def remove_symlink(path)
      if File.exist? path
        say_status "remove", path
        if File.symlink? path
          File.delete path
        else
          say_status "error", "#{path} is not a symlink - not removing"
        end
      end

    end
  end
end
