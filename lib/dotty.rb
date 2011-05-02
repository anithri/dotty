# encoding: utf-8

require 'yaml'
require 'hashie'
require 'thor'
require 'pathname'

require 'dotty/helpers'
require 'dotty/app'
require 'dotty/profile'
require 'dotty/repository'
require 'dotty/repository_actions'

module Dotty
  class Error < StandardError; end
  class RepositoryNotFoundError < Error; end
  class InvalidRepositoryNameError < Error; end
end
