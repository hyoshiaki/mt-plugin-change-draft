#!/usr/bin/perl
package MT::ChangeDraft::Test;
use strict;
use warnings;
use FindBin;
use lib ("$FindBin::Bin/../lib", "$FindBin::Bin/../extlib");
use Test::More;

use MT;
use base qw( MT::Tool );

my $VERSION = 0.1;
sub version { $VERSION }

sub help {
    return <<'HELP';
OPTIONS:
    -h, --help             shows this help.
HELP
}

sub usage {
    return '[--help]';
}


## options
my ( $blog_id, $user_id, $verbose );

sub options {
    return (
    )
}

sub main {
    my $mt = MT->instance;
    my $class = shift;

    $verbose = $class->SUPER::main(@_);

    use_ok('MT::ChangeDraft::Util');
    use_ok('MT::ChangeDraft::CMS');
    use_ok('MT::ChangeDraft::Entry');
    use_ok('MT::ChangeDraft::Listing');
}

__PACKAGE__->main() unless caller;

done_testing();


