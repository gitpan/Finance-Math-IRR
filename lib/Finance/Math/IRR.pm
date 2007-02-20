#################################################################
#
#   Finance::Math::IRR - Calculate the internal rate of return of a cash flow
#
#   $Id: IRR.pm,v 1.7 2007/01/04 13:11:13 erwan Exp $
#
#   061215 erwan Started implementation
#   061218 erwan Differentiate bugs from failures when calling secant() and brent()
#   061218 erwan Handle precision correctly
#   061218 erwan Support cashflows with only 0 amounts
#   070220 erwan Support when secant converges toward a non root value
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

our $VERSION = '0.06';

#----------------------------------------------------------------
#
#   _crash - die with a usable error description
#

sub _crash {
    my($method,$poly,$args,$err) = @_;

    croak "BUG: something went wrong while calling Math::Polynom::$method with the arguments:\n".
	Dumper($args)."on the polynomial:\n".
	Dumper($poly)."the error was: [$err]\n".
	"Please email all this output to erwan\@cpan.org\n";
}

#----------------------------------------------------------------
#
#   xirr - calculate the internal rate of return of a cash flow
#

sub xirr {
    my $precision = 0.001; # default precision seeked on irr, ie 0.1%
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
    my $all_zeros = 1;
    while (my($date,$amount) = each %cashflow) {
	croak "ERROR: the provided cashflow contains undefined values"           if (!defined $date || !defined $amount);
	croak "ERROR: invalid date in the provided cashflow [$date]"             if ($date !~ /^\d\d\d\d-\d\d-\d\d$/);
	croak "ERROR: invalid amount in the provided cashflow at date [$date]"   if (!looks_like_number($amount));
	$all_zeros = 0 if ($amount != 0);
    }

    croak "ERROR: precision is not a valid number"        if (!defined $precision || !looks_like_number($precision));
    croak "ERROR: the cashflow you provided is too small" if (scalar keys %cashflow < 2);

    # if the cashflow only contains 0 amounts, the irr is 0%
    return 0 if ($all_zeros);

    # we want $precision on the irr, but can only steer the precision of 1/(1+irr), hence this ratio, that
    # should insure us the given precision even on the irr for irrs up to 1000%
    $precision = $precision / 1000;

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
	# secant failed. let's make sure it was not a bug
	if ($poly->error != Math::Polynom::ERROR_NAN && 
	    $poly->error != Math::Polynom::ERROR_DIVIDE_BY_ZERO && 
	    $poly->error != Math::Polynom::ERROR_MAX_DEPTH &&
	    $poly->error != Math::Polynom::ERROR_NOT_A_ROOT) 
	{
	    # ok, the method did not fail, something else did
	    _crash("secant", $poly, {p0 => 0.5, p1 => 1, precision => $precision, max_depth => 50}, $@);
	}
	
	
	# let's find two points where the polynomial is positive respectively negative
	my $i = 1;
	while ( (!defined $poly->xneg || !defined $poly->xpos) && $i <= 1024 ) {
	    $poly->eval( $i );
	    $poly->eval( -1+10/($i+9) );
	    $i++;
	}
	
	if ( !defined $poly->xneg || !defined $poly->xpos ) {
	    # we did not find 2 points where the polynomial is >0 and <0, so we can't use Brent's method (nor the bisection)
	    return undef;
	}

	eval {
	    # try finding the IRR with Brent's method
	    $root = $poly->brent( a => $poly->xneg, b => $poly->xpos, precision => $precision, max_depth => 50);
	};
	
	if ($@) {
	    # Brent's method failed

	    if ($poly->error != Math::Polynom::ERROR_NAN && 
		$poly->error != Math::Polynom::ERROR_MAX_DEPTH &&
		$poly->error != Math::Polynom::ERROR_NOT_A_ROOT)
	    {
		# looks like a bug, either in Math::Polynom's implementation of Brent of in the arguments we sent to it
		_crash("brent", $poly, {a => $poly->xneg, b => $poly->xpos, precision => $precision, max_depth => 50}, $@);
	    }

	    # Brent's method was unable to approximate the root
	    return undef;
	}
    }
    
    if ($root == 0) {
	# that would mean IRR = infinity, which is kind of not plausible
	return undef;
    }

    return -1 + 1/$root;
}

1;

__END__

=head1 NAME

Finance::Math::IRR - Calculate the internal rate of return of a cash flow

=head1 SYNOPSIS

    use Finance::Math::IRR;

    # we provide a cash flow
    my %cashflow = (
        '2001-01-01' => 100,
        '2001-03-15' => 250.45,
        '2001-03-20' => -50,
        '2001-06-23' => -763.12,  # the last transaction should always be <= 0
    );

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

The approach of Finance::Math::IRR is to try to approximate one of the polynomial's 
roots with the secant method. If it fails, Brent's method is tried. However, Brent's
method requires to know of an interval such that the polynomial is positive on one
end of the interval and negative on the other. Finance::Math::IRR searches for such
an interval by trying systematically a sequence of points. But it may fail to find
such an interval and therefore fail to approximate the cashflow's IRR:


=head1 API

=over 4

=item xirr(%cashflow, precision => $float)

Calculates an approximation of the internal rate of return (IRR) of 
the provided cashflow. The returned IRR will be within I<$float> 
of the exact IRR. The cashflow is a hash with the following structure:

    my %cashflow = (
        # date => transaction_amount
        '2006-01-01' => 15,
        '2006-01-15' => -5,
        '2006-03-15' => -8,
    );

To get the IRR in percent, multiply xirr's result by 100.

If I<precision> is omitted, it defaults to 0.001, yielding 0.1%
precision on the resulting IRR.

I<xirr> may fail to find the IRR, in which case it returns undef.

I<xirr> will croak if you feed it with junk.

=back

=head1 DISCUSSION

Finding the right strategy to solve the IRR equation is tricky.
Finance::Math::IRR uses a slightly different technique than the
corresponding XIRR function in Gnumeric.

Gnumeric uses first Newton's method to approximate the IRR. If
it fails, it evaluates the polynomial on a sequence of points 
( '-1 + 10/(i+9)' and 'i' with i from 1 to 1024), hoping to find 
2 points where the polynomial
is respectively positive and negative. If it finds 2 such points,
gnumeric's XIRR then uses the bisection method on their interval.

Finance::Math::IRR has a slightly different strategy. It uses the
secant method instead of Newton's, and Brent's method instead of
the bisection. Both methods are believed to be superior to their
Gnumeric counterparts. Finance::Math::IRR performs additional
controls to guaranty the validity of the result, such as controlling
that the root candidate returned by Secant and Brent really are roots.

=head1 BUGS AND LIMITATIONS

This module has been used in recquiring production
environments and thoroughly tested. It is therefore
believed to be robust.

Yet, the method used in xirr may fail to find the IRR even
on cashflows that do have an IRR. If you happen to find
such an example, please email it to the author at
C<< <erwan@cpan.org> >>.

=head1 SEE ALSO

See Math::Polynom, Math::Function::Roots.

=head1 VERSION

$Id: IRR.pm,v 1.7 2007/01/04 13:11:13 erwan Exp $

=head1 THANKS

Kind thanks to Gautam Satpathy (C<< gautam@satpathy.in >>) who provided me with his own implementation
of XIRR written in Java. Its source can be found at http://www.satpathy.in/jxirr/index.html.

Thanks to the team of Gnumeric for releasing their implementation of XIRR
in open source. For the curious, the code for XIRR is available in
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









