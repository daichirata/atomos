require 'rubygems'
require 'rake'
require 'spec/rake/spectask'

task :default => :spec

Spec::Rake::SpecTask.new do |t|
	t.spec_opts = ['--format specdoc', '--color']
	t.spec_files = FileList['spec/*_spec.rb']
end
