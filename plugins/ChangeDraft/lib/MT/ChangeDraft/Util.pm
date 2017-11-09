package MT::ChangeDraft::Util;

use strict;
use warnings;
use base qw(Exporter);

use Data::Dumper;

our @EXPORT = qw(plugin pp list_shortcuts plugin_config query_config format_acted_on);

sub plugin { MT->component('ChangeDraft') }

sub pp { print STDERR Dumper(@_); }

sub list_shortcuts {
    my $shortcuts = MT->registry('changedraft', 'list_shortcuts');
    my @filtered =
        map
            { $shortcuts->{$_} }
        sort
            { ($shortcuts->{$a}->{order} || 1000) <=> ($shortcuts->{$b}->{order} || 1000) }
        keys
            %$shortcuts;

    \@filtered;
}

sub plugin_config {
    my ( $blog_id, $param ) = @_;
    my $scope = $blog_id ? "blog:$blog_id" : "system";

    my %config;
    plugin->load_config(\%config, $scope);

    my $saving = 0;
    if ( ref $param eq 'HASH' ) {
        foreach my $k ( %$param ) {
            $config{$k} = $param->{$k};
        }
        $saving = 1;
    } elsif ( ref $param eq 'CODE' ) {
        $saving = $param->(\%config);
    }

    plugin->save_config(\%config, $scope) if $saving;
    \%config;
}

sub query_config {
    my $blog_id = shift;
    my %config;

    my $system_config = plugin_config(0);
    my $blog_config = $blog_id ? plugin_config($blog_id) : $system_config;
    my $single;
    foreach my $q ( @_ ) {
        $single = $config{$q} = 0;
        if ( $q eq 'enabled' ) {
            if ( my $enabled = $blog_config->{change_draft_enabled} ) {
                $enabled = $system_config->{change_draft_enabled} ? 1 : 0 if $enabled == 2;
                $config{$q} = $enabled;
            }
        } else {
            $config{$q} = $system_config->{"change_draft_$q"};
        }
        $single = $config{$q};
    }

    scalar @_ == 1 ? $single : \%config;
}

sub multi_draft_for_shortcut_status {
    query_config(0, 'multi_drafts');
}

sub format_acted_on {
    my ( $ts, %args ) = @_;
    my $user = $args{user};
    my $blog = $args{blog};

    my $time = $args{time} || time;

    my $is_relative = $args{is_relative};
    unless ( defined $is_relative ) {
        $is_relative = $user
            ? ( ( $user->date_format || 'relative' ) eq 'relative' ? 1 : 0 )
            : 1;
    }

    my $date_format = $args{date_format};
    unless ( defined $date_format ) {
        require MT::App::CMS;
        $date_format = MT::App::CMS::LISTING_DATE_FORMAT();
    }

    my $lang = $args{lang};
    unless ( defined $lang ) {
        $lang = $user
            ? $user->preferred_language
            : MT->config('DefaultLanguage');
    }

    $is_relative
        ? MT::Util::relative_date( $ts, time, $blog )
        : MT::Util::format_ts(
            $date_format,
            $ts,
            $blog,
            $lang
        );
}

1;