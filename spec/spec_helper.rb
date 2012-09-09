$:.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'rubygems'
require 'rspec'
require 'rack/test'
require 'wsse'
require 'rexml/document'
require 'atomos'

include Atomos
Atomos.configure

