#
#   $Id: 02_test_irr_errors.t,v 1.3 2006/12/15 17:39:57 erwan Exp $
#
#   test xirr against garbage input
#

use strict;
use warnings;
use Test::More tests => 11;
use lib "../lib/";

use_ok('Finance::Math::IRR');

# test error handling
eval { xirr(); };
ok( (defined $@ && $@ =~ /odd number of arguments/), "test check of argument number");

eval { xirr(1,2,3); };
ok( (defined $@ && $@ =~ /odd number of arguments/), "test check of argument number");

eval { xirr('bob' => undef); };
ok( (defined $@ && $@ =~ /contains undefined values/), "test check of undefined arguments in cashflow");

eval { xirr('precision' => undef); };
ok( (defined $@ && $@ =~ /precision is not a valid number/), "test check of undefined precision");

eval { xirr('precision' => 1.32); };
ok( (defined $@ && $@ =~ /cashflow .* too small/), "test check of empty cashflow");

eval { xirr('precision' => 1.32, 'bilou' => 1); };
ok( (defined $@ && $@ =~ /invalid date/), "test check of dates in cashflow");

eval { xirr('precision' => 1.32, '2001-11-01' => 'abc'); };
ok( (defined $@ && $@ =~ /invalid amount/), "test check of amounts in cashflow");

eval { xirr('precision' => 1.32, '2001-11-01' => 12.3); };
ok( (defined $@ && $@ =~ /cashflow .* too small/), "test check of amounts in cashflow");

my $v;
eval { $v = xirr('precision' => 1.32, '2001-01-01' => 10, '2002-01-01' => -20); };
ok( (!defined $@ || $@ eq ''), "test with valid arguments");
is($v,1,"and this simple cashflow has a 100% growth");







