#
#   $Id: 03_test_irr.t,v 1.2 2006/12/15 17:42:11 erwan Exp $
#
#   test Finance::Math::IRR against a number of cashflows
#   verified with excell's XIRR
#

use strict;
use warnings;
use Test::More tests => 5;
use lib "../lib/";

use_ok('Finance::Math::IRR');

my $count = 0;

sub test_xirr {
    my($expect,%args) = @_;
    my $v = xirr(%args);
    my $p = $args{precision} || 0.001;

    $count++;

    if (defined $expect) {
	if (defined $v) {
	    ok(abs($v - $expect) < $p, "cashflow $count has IRR=$v, which is whithin $p of $expect");
	} else {
	    ok(0,"cashflow $count has IRR=undef, while expectin $expect");
	}
    } else {
	is($v, undef, "cashflow $count has IRR=undef as expected");
    }
}

test_xirr(1, 'precision' => 1.32, 
	  '2001-01-01' => 10, 
	  '2002-01-01' => -20,
	  );

# a real life example:
test_xirr(-0.019632, precision => 0.00001,
	  '1995-01-28' =>  13.50, 
	  '1995-02-28' =>  13.50, 
	  '1995-03-28' =>  13.50, 
	  '1995-04-28' =>  13.50, 
	  '1995-05-28' =>  13.50, 
	  '1995-06-28' =>  13.50, 
	  '1995-07-28' =>  13.50, 
	  '1995-08-28' =>  13.50, 
	  '1995-09-28' =>  13.50, 
	  '1995-10-28' =>  13.50, 
	  '1995-11-28' =>  13.50, 
	  '1995-12-28' =>  13.50, 
	  '1997-01-28' =>  131.50, 
	  '1997-02-28' =>  131.50, 
	  '1997-03-28' =>  131.50, 
	  '1997-04-28' =>  131.50, 
	  '1997-05-28' =>  131.50, 
	  '1997-06-28' =>  131.50, 
	  '1997-07-28' =>  131.50, 
	  '1997-08-28' =>  131.50, 
	  '1997-09-28' =>  131.50, 
	  '1997-10-28' =>  131.50, 
	  '1997-11-28' =>  131.50, 
	  '1997-12-28' =>  131.50, 
	  '1998-01-28' => -64.33, 
	  '1998-02-28' => -64.33, 
	  '1998-03-28' => -64.33, 
	  '1998-04-28' => -64.33, 
	  '1998-05-28' => -64.33, 
	  '1998-06-28' => -64.33, 
	  '1998-07-28' => -64.33, 
	  '1998-08-28' => -64.33, 
	  '1998-09-28' => -64.33, 
	  '1998-10-28' => -64.33, 
	  '1998-11-28' => -64.33, 
	  '1998-12-28' => -64.33, 
	  '1999-01-28' =>  23.17, 
	  '1999-02-28' =>  23.17, 
	  '1999-03-28' =>  23.17, 
	  '1999-04-28' =>  23.17, 
	  '1999-05-28' =>  23.17, 
	  '1999-06-28' =>  23.17, 
	  '1999-07-28' =>  23.17, 
	  '1999-08-28' =>  23.17, 
	  '1999-09-28' =>  23.17, 
	  '1999-10-28' =>  23.17, 
	  '1999-11-28' =>  23.17, 
	  '1999-12-28' =>  23.17, 
	  '2001-03-15' =>  -4.00, 
	  '2001-03-22' =>  44.03,
	  '2001-07-12' =>  -8.00, 
	  '2001-08-16' =>  -8.00, 
	  '2001-09-13' =>  -8.00, 
	  '2001-10-11' =>  -8.00, 
	  '2001-11-15' =>  -8.00, 
	  '2001-12-13' =>  -8.00, 
	  '2002-01-15' =>  -6.00, 
	  '2002-02-13' =>  -6.00, 
	  '2002-03-13' =>  -6.00, 
	  '2002-04-18' =>  -6.00, 
	  '2002-04-24' =>  -1091.59,
	  );

test_xirr(-0.1243234, precision => 0.00001,
	  '2002-01-01' =>     1161.91,
	  '2002-01-15' =>       -6.00, 
	  '2002-02-13' =>       -6.00, 
	  '2002-03-13' =>       -6.00, 
	  '2002-04-18' =>       -6.00, 
	  '2002-04-24' =>    -1091.59,
	  ); 

# that one has no solution:
test_xirr(undef, precision => 0.00001,
	  '2001-01-01' =>      705.57,
	  '2001-03-22' =>      563.43,
	  '2001-12-31' =>        0.00,
	  ); 





