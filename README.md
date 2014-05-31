Lines - structured logs for humans
==================================
[![Build
Status](https://travis-ci.org/zimbatm/lines-ruby.png)](https://travis-ci.org/zimbatm/lines-ruby)

A ruby implementation of the
[lines](https://github.com/zimbatm/lines) format.

STATUS: WORK IN PROGRESS
========================

Example
-------

```ruby
require 'lines'

Lines.dump(foo: 3) #=> "foo=3"

Lines.load("foo=3") #=> {"foo"=>3}
```

