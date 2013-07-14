Lines - structured logs for humans
==================================
[![Build
Status](https://travis-ci.org/zimbatm/lines-ruby.png)](https://travis-ci.org/zimbatm/lines-ruby)

An oppinionated logging library that implement the
[lines](https://github.com/zimbatm/lines) format.

* Log everything in development AND production.
* Logs should be easy to read, grep and parse.
* Logging something should never fail.
* Let the system handle the storage. Write to syslog or STDERR.
* No log levels necessary. Just log whatever you want.

STATUS: WORK IN PROGRESS
========================

Doc is still scarce so it's quite hard to get started. I think reading the
lib/lines.rb should give a good idea of the capabilities.

Lines.id is a unique ID generator that seems quite handy but I'm not sure if
it should be part of the lib or not.

It would be nice to expose a method that resolves a context into a hash. It's
useful to share the context with other tools like an error reporter. Btw,
Sentry/Raven is great.

There is a parser in the lib but no credible direct consumption path.

Quick intro
-----------

```ruby
require 'lines'

# Setups the outputs. IO and Syslog are supported.
Lines.use($stdout, Syslog)

# All lines will be prefixed by the global context
Lines.global['at'] = proc{ Time.now }

# First example
Lines.log(foo: 'bar') # logs: at=2013-07-14T14:19:28Z foo=bar

# If not a hash, the argument is transformed. A second argument is accepted as
# a hash
Lines.log("Hey", count: 3) # logs: at=2013-07-14T14:19:28Z msg=Hey count=3

# You can also keep a context
class MyClass < ActiveRecord::Base
  attr_reader :lines
  def initialize
    @lines = Lines.context(my_class_id: self.id)
  end

  def do_something
    lines.log("Something happened")
    # logs: at=2013-07-14T14:19:28Z msg='Something happeend' my_class_id: 2324
  end
end
```

Features
--------

* Simple to use
* Thread safe (if the IO#write is)
* Designed to not raise exceptions (unless it's an IO issue)
* Lines.logger is a backward-compatible Logger in case you want to retrofit
* require "lines/active_record" for sane ActiveRecord logs
* "lines/rack_logger" is a logging middleware for Rack
* Lines.load and Lines.dump to parse and generate 'lines'

There's also a fork of lograge that you can use with Rails. See
https://github.com/zimbatm/lograge/tree/lines-output

Known issues
------------

Syslog seems to truncate lines longer than 2056 chars and Lines makes if very
easy to put too much data.

Lines logging speed is reasonable but it could be faster. It writes at around
5000 lines per second to Syslog on my machine.

Inspired by
-----------

 * Scrolls : https://github.com/asenchi/scrolls
 * Lograge : https://github.com/roidrage/lograge
