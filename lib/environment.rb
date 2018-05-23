ROOT_DIR = "/home/dev/projects/viaf-export" unless defined?(ROOT_DIR)
Dir['./utils/*.rb'].each {|file| require file }
Dir['./lib/transformator.rb'].each {|file| require file }
Dir['./lib/*.rb'].each {|file| require file }
require 'pry'
require 'awesome_print'
require 'json'
require 'yaml'
