Lines - structured logs for humans
==================================
[![Build
Status](https://travis-ci.org/zimbatm/lines-ruby.svg?branch=master)](https://travis-ci.org/zimbatm/lines-ruby)

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

Uses
----

CLI pipes format

Structued logging


Generator TODO
--------------

Add a max_length option

Make sure the output is encoded as a UTF-8 string

Parser TODO
-----------

Implement the max_nesting option

Different parsing modes. Strict and non-strict. Type templates.

Multi-line parsing.


