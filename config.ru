if defined?(Encoding) && Encoding.respond_to?('default_external')
   Encoding.default_external = 'utf-8'
end

$:.unshift File.dirname(__FILE__)
$:.unshift File.join(File.dirname(__FILE__), 'lib')

require 'rubygems'
require 'bundler'
Bundler.setup

require 'atomos'
run Atomos.new
