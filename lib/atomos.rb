require 'yaml'
require 'atomos/application'
require 'atomos/models'

module Atomos
  VERSION = '0.2.1'.freeze

  class << self
    def new
      configure
      Application
    end

    def configure
      DataMapper.setup(:default, config[:database][env])
      DataMapper.auto_migrate!

      Application.set(config)
    end

    def env
      case env = ENV['RACK_ENV']
      when 'production', 'test' then env.to_sym
      else :development
      end
    end

    def config
      unless @config
        root = File.expand_path('..', File.dirname(__FILE__))
        file = File.exist?("#{root}/config.yml") ? 'config.yml' : 'config.sample.yml'
        @config = YAML.load(ERB.new(File.read("#{root}/#{file}")).result(binding))
      end
      @config
    end
  end
end
