#################################################################
#
#   Finance::Math::IRR - Calculate the internal rate of return of a cash flow
#
#   $Id: IRR.pm,v 1.2 2006/12/15 17:39:57 erwan Exp $
#
#   061215 erwan Started implementation
#

package Finance::Math::IRR;

use 5.006;
use strict;
use warnings;
use Carp qw(confess croak);
use Data::Dumper;
use Math::Polynom;
use Date::Calc qw(Delta_Days);
use Scalar::Util qw(looks_like_number);
use base qw(Exporter);

our @EXPORT = qw(xirr);

our $VERSION = '0.01';

#----------------------------------------------------------------
#
#   xirr - calculate the internal rate of return of a cash flow
#

sub xirr {
    my $precision = 0.001;
    my $guess = 0.1;
    my %cashflow;
    my $root;

    croak("ERROR: xirr() got an odd number of arguments. this can not be correct") if (!scalar(@_) || scalar(@_) % 2);

    %cashflow = @_;

    # parse arguments
    if (exists $cashflow{precision}) {
	$precision = $cashflow{precision};
	delete $cashflow{precision};
    }
    
    # TODO: compute the precision as provided to secant/brent to get this precision on IRR

    # check arguments
    while (my($date,$amount) = each %cashflow) {
	croak "ERROR: the provided cashflow contains undefined values"           if (!defined $date || !defined $amount);
	croak "ERROR: invalid date in the provided cashflow [$date]"             if ($date !~ /^\d\d\d\d-\d\d-\d\d$/);
	croak "ERROR: invalid amount in the provided cashflow at date [$date]"   if (!looks_like_number($amount));
    }
    
    croak "ERROR: precision is not a valid number"        if (!defined $precision || !looks_like_number($precision));
    croak "ERROR: the cashflow you provided is too small" if (scalar keys %cashflow < 2);

    # build the polynomial whose solution is x=1/(1+IRR)
    my @sorted_keys = sort keys %cashflow;
    my @date_start = split(/-/,$sorted_keys[0]);
    croak "BUG: expected 3 arguments after splitting [".$sorted_keys[0]."]" if (scalar @date_start != 3);

    my %coeffs;
    
    while (my($date,$amount) = each %cashflow) {
	my $ddays = Delta_Days(@date_start, split(/-/,$date));
	$coeffs{$ddays/365} = $amount;
    }
    
    my $poly = Math::Polynom->new(%coeffs);
    
    # try finding the IRR with the secant method
    eval {
	$root = $poly->secant(p0 => 0.5, p1 => 1, precision => $precision, max_depth => 50);
    };
    
    if ($@) {
	# secant failed. let's find two points where the polynomial is positive respectively negative
	my $i = 1;
	while ( (!defined $poly->xneg || !defined $poly->xpos) && $i <= 1024 ) {
	    $poly->eval( $i );
	    $poly->eval( -1+10/($i+9) );
	    $i++;
	}
	
	if ( !defined $poly->xneg || !defined $poly->xpos ) {
	    # we did not find 2 points where the polynomial is >0 and <0. can't use Brent's method (nor the bisection)
	    return undef;
	}

	eval {
	    # try finding the IRR with Brent's method
	    $root = $poly->brent( a => $poly->xneg, b => $poly->xpos, precision => $precision, max_depth => 50);
	};
	
	if ($@) {
	    # even Brent failed.
	    # that must be an interesting cash flow! PLEASE!! mail it to erwan@cpan.org!!
	    return undef;
	}
    }
    
    if ($root == 0) {
	# that would mean IRR = infinity, which is kind of not plausible
	return undef;
    }

    return 1/$root -1;
}

1;

__END__

=head1 NAME

Finance::Math::IRR - Calculate the internal rate of return of a cash flow

=head1 SYNOPSIS

    use Finance::Math::IRR;

    # we provide a cash flow
    my $cashflow = {
        '2001-01-01' => 100,
        '2001-03-15' => 250.45,
        '2001-03-20' => -50,
        '2001-06-23' => -763.12,  # the last transaction should always be <= 0
    };

    # and get the internal rate of return for this cashflow
    # we want a precision of 0.1%
    my $irr = xirr(%cashflow, precision => 0.001);

    # or simply: my $irr = xirr(%cashflow);

    if (!defined $irr) {
        die "ERROR: xirr() failed to calculate the IRR of this cashflow\n";
    }

=head1 DESCRIPTION

The internal rate of return (IRR) is a powerfull tool when
evaluating the behaviour of a cashflow. It is typically used 
to assess whether an investment will yield profit. But since
you are reading those lines, I assume you already know what 
an IRR is about.

In this module, the internal rate of return is calculated in a similar way
as in the function XIRR present in both Excell and Gnumeric. This 
means that cash flows where transactions come at irregular intervals 
are well supported, and the rate is a yearly rate.

An IRR is obtained by finding the root of a polynomial where each coefficient is
the amount of one transaction in the cash flow, and the power of the 
corresponding coefficient is the number of days between that transaction
and the first transaction divided by 365 (one year). Note that it isn't 
a polynomial in the traditional meaning since its powers may have decimals or
be less than 1.

There is no universal way to solve this equation analytically. Instead,
we have to find the polynomial's root with various root finding algorithms.
That's where the fun starts...

The approach of Finance::Math::IRR is to try to solve the IRR equation
using the secant method. If it fails, Brent's method is tried. Brent's
method is guaranteed to succeed but requires that we know of 2 values
where the polynomial is respectively positive and negative. Finance::Math::IRR
uses reasonable heuristics to guess such values. But it may fail.




=head1 API

=over 4

=item xirr(%cashflow, precision => $float)

Calculates an approximation of the internal rate of return (IRR) of 
the provided cash flow. The returned IRR will be within I<$float> 
of the exact IRR. The cashflow is a reference to a hash having the
following structure:

    my %cashflow = (
        # date => transaction-amount
        '2006-01-01' => 15,
        '2006-01-15' => -5,
        '2006-03-15' => -8,
    );

To get the IRR in percent, multiply the xirr's result by 100.

If I<precision> is omitted, it defaults to 0.001, yielding 0.1%
precision on the resulting IRR.

I<xirr> may fail to find the IRR, in which case it returns undef.

I<xirr> will croak if you feed it with junk.

=back

=head1 DISCUSSION

Finding the right strategy to solve the IRR equation is tricky.
Finance::Math::IRR uses a slightly different technique as the
corresponding XIRR function in Gnumeric.

Gnumeric uses first Newton's method to approximate the IRR. If
it fails, it evaluates the polynomial on a sequence of points ( '-1 + 10/(i+9)' and 'i' 
with i from 1 to 1024), hoping to find 2 points where the polynomial
is respectively positive and negative. If it finds 2 such points,
gnumeric's XIRR then uses the bisection method on their interval.

Finance::Math::IRR has a slightly different strategy. It uses the
secant method instead of Newton's, and Brent's method instead of
the bisection. Both methods are believed to be more robust than
their Gnumeric counterparts.


=head1 BUGS AND LIMITATIONS

This module has been used in recquiring production
environments and thoroughly tested. It is therefore
believed to be robust.

Yet, the method used in xirr may fail to find the IRR even
on cash flows that do have an IRR. If you happen to find
such an example, please email it to the author at
C<< <erwan@cpan.org> >>.

=head1 SEE ALSO

See Math::Polynom, Math::Function::Roots.

=head1 VERSION

$Id: IRR.pm,v 1.2 2006/12/15 17:39:57 erwan Exp $

=head1 THANKS

Kind thanks to Gautam Satpathy who provided me with his own implementation
of XIRR written in Java.

Thanks to the team of Gnumeric for releasing their implementation of XIRR
in open source. For the curious, the source code of XIRR is available in
the sources of gnumeric in the file 'plugins/fn-financial/functions.c' (as
of gnumeric 1.6.3).

=head1 AUTHOR

Erwan Lemonnier C<< <erwan@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

This code is distributed under the same terms as Perl itself.

=head1 DISCLAIMER OF WARRANTY

This is free code and comes with no warranty. The author declines any personal 
responsibility regarding the use of this code or the consequences of its use.

=cut









