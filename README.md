Resmon
======
A lightweight utility for local host monitoring that can be queried by tools
such as Nagios over HTTP. One of the main design goals is portability: that
resmon should require nothing more than a default install of Perl. Built with
the philosophy that "we are smart because we are dumb," that is, local
requirements should be minimal to ease deployment on multiple platforms.

Requirements
------------
Perl 5.  Individual modules may require additional utilties (e.g. the svn
command).

Apps supporting Resmon output
-----------------------------
 * Munin with the [circonus-munin](http://github.com/adamhjk/circonus-munin) bridge.

Documentation
-------------
Available in the [resmon wiki](https://labs.omniti.com/labs/resmon/wiki/)

Copyright
---------
Copyright &copy; 2013 OmniTI Computer Consulting, Inc.  See LICENSE for details.
