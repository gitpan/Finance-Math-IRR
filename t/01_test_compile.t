#
#   $Id: 01_test_compile.t,v 1.1 2006/12/15 14:36:09 erwan Exp $
#
#   test that Finance::Math::IRR compiles
#

use strict;
use warnings;
use Test::More tests => 1;
use lib "../lib/";

use_ok('Finance::Math::IRR');
