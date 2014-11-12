
0.9.1 / 2014-11-12
==================

Bump after broken release process.

0.9.0 / 2014-11-12
==================

Moved the logging part to a separate library called u-log.
http://rubygems.org/gems/u-log

 * REMOVED: All logging parts
 * NEW: max_bytesize directive to limit line length
 * FIX: BasicObject serialization for ruby 2.1+
 * Tons of cleanup

0.2.0 / 2013-07-15 
==================

 * Use benchmark-ips for benchs
 * Fixes serialization of Date objects
 * Lines now outputs to $stderr by default.
 * Lines.use resets the global context.
 * Improved the doc
 * Lines.log now returns nil instead of the logged object.
 * Support parsing lines that end with \r\n or spaces
 * Add Lines.load and Lines.dump for JSON-like functionality
 * Introduced a hand-written parser that performs 200x faster
 * Differentiate units with a : sign to ensure their parsability
 * Escape strings that contain an equal sign
 * Change the default max_depth from 3 to 4
 * Make sure ActiveRecord's log subscriber is loaded

0.1.27 / 2013-07-10 
===================

 * Fixes AR's notification by changing the ordering
 * Update the ActiveRecord log subscriber to work with AR 4.0.0

0.1.26 / 2013-07-10 
===================

 * Fixes double outputs from ActiveRecord

0.1.25 / 2013-07-10 : the "hopefully all syslog issues are fixes" edition
===================

 * Change the logic of opening syslog with the app_name.
 * Fixes syslog level extraction
 * Fixes incorrect flag masks when opening syslog

0.1.24 / 2013-07-09 
===================

 * Fixes escaping issue with Syslog

0.1.22 / 2013-06-27 
===================

 * Fixes issue where Syslog is not recognized as an outputter
 * Fixes issue when Lines.use is given an array of outputters

0.1.21 / 2013-06-27 
===================

 * Return self when silencing the Rack::CommonLogger
 * Use Lines as the default ActiveRecord::Base logger
 * Catch errors from global procs

