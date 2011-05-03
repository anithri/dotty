# Dotty

Dotty is a command line tool for managing your dotfiles (written in Ruby, using [Thor](https://github.com/wycats/thor/))

## Features
* Store dotfiles in multiple git repositories
* Automate symlinking and other bootstrapping of dotfile repositories
* Support profiles so that it's easy to switch between sets of dotfiles
* Shows uncommited changes / unpushed commits for your dotfile repos
* Easily update submodules in your dotfile repos

## How dotty interacts with dotty repositories

By using one or more of the approaches below, you instruct dotty on how it can boostrap and implode (opposite of bootstrap) your dotty repository.

### dotfiles/

Dotty will symlink files and directories in the root your repos dotfiles/ directory, relative to ~.
You can symlink stuff to sub directories of ~ by using the in+subdir directory naming convention.

#### Example

    dotfiles/.vim             => ~/.vim
    dotfiles/in+.ssh/config   => ~/.ssh/config
    dotfiles/in+a/in+b/c      => ~/a/b/c

### dotty-symlinks.yml

If you want more control over the symlinking, you can create a dotty-symlink.yml in the repo root.

#### Example
    
    file_in_repo:filename_in_home_dir

### dotty-repository.thor

If you want to do more than symlinking, you can create a dotty-repository.thor that implements the 'bootstrap' and 'implode' thor tasks.
The class must be named "DottyRepository".

#### Example

    class DottyRepository < Thor
      include Thor::Actions

      desc "bootstrap", "Bootstrap this repo"
      def bootstrap
        # Do stuff here
      end

      desc "implode", "Implode this repo"
      def implode
        # Do stuff here
      end
    end

## Installation / usage

    gem install dotty

### Requirements
* ruby (tested on 1.9.2) and rubygems
* git (the git executable must be in your $PATH)

### Commands

    $ dotty       (or dottie if you have graphviz installed which has a dotty executable)

    Tasks:
      dotty add <name> <git repo url>             # Add existing dotty git repository
      dotty bootstrap [name]                      # Bootstrap specified or all dotty repositories. Usually involves making symlinks in your home dir.
      dotty create <name> <git repo url>          # Create a new git repository with the specified git repo url as origin
      dotty create_profile <profile name>         # Create a new profile
      dotty execute [repo name] <command to run>  # For specified or all repositories, run given command
      dotty help [TASK]                           # Describe available tasks or one specific task
      dotty implode [name]                        # Opposite of bootstrap
      dotty import_repos <yaml_file_location>     # Imports dotty repositories from the specified yaml file location (http works)
      dotty list                                  # List installed dotty repositories
      dotty profile [profile name]                # Switch to given profile or show current profile if no profile name is given
      dotty profiles                              # List profiles
      dotty remove <name>                         # Remove dotty repository
      dotty remove_profile <profile name>         # Remove given profile
      dotty update [name]                         # Update specified or all dotty repositories
      dotty update_submodules [name]              # For specified or all repositories, for submodules and pull

### Creating an example dotty repository

    $ dotty create dotty-test git@github.com:trym/dotty-test

     create repo  dotty-test [git@github.com:trym/dotty-test]
             run  git init /Users/trym/.dotty/default/dotty-test from "."
    Initialized empty Git repository in /Users/trym/.dotty/default/dotty-test/.git/
             run  git remote add origin git@github.com:trym/dotty-test from "./.dotty/default/dotty-test"
          create  .dotty/default/dotty-test/dotfiles
          create  .dotty/default/dotty-test/README.md

    $ cd ~/.dotty/default/dotty-test
    $ touch dotfiles/testfile
    $ dotty bootstrap dotty-test
       bootstrap  dotty-test
          create    sers/trym/testfile

    $ ls -al ~/testfile
    lrwxr-xr-x  1 trym  staff  55 May  3 01:05 /Users/trym/testfile -> /Users/trym/.dotty/default/dotty-test/dotfiles/testfile

    $ dotty implode dotty-test
         implode  dotty-test
          remove  /Users/trym/testfile
 
## License

Released under the LGPL License. See the LICENSE file for further details.


