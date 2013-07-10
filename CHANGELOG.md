
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

