#!/usr/bin/env ruby
# Why use -- prefixes in command-line programs ?
#
# Here's how we can use lines for a nicer experience:
#
# ./cli.rb foo=333 bar=baz 'xxx=[3 4 #t]'
#
# Actually zsh makes it less friendly because [] and {} are interpreted
#
# FIXME: cli.rb foo='a b'
# FIXME: cli.rb --foo=abc

$:.unshift File.expand_path('../../lib', __FILE__)
require 'lines'
p ARGV
args = Lines.load(ARGV.join(' '))
p args
