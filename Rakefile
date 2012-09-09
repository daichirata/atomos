require 'rubygems'
task :default => :spec

task 'spec:setup' do
  ENV['RACK_ENV'] = 'test'
end

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec => 'spec:setup') do |spec|
    spec.pattern = 'spec/*_spec.rb'
    spec.rspec_opts = ['-cfs']
  end
rescue LoadError => e
  p e
end
