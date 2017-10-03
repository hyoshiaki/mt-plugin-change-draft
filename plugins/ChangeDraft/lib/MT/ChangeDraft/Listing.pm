package MT::ChangeDraft::Listing;

use strict;
use warnings;

use MT::Entry;
use MT::Page;
use MT::ChangeDraft::Util;
use MT::ChangeDraft::Entry;

use MT::Util;

our %objects = (
    entry => {
        code => \&action_new_entry_change_draft,
        permit_action => {
            permit_action => 'edit_own_entry',
            at_least_one => 1,
        },
    },
    page => {
        code => \&action_new_page_change_draft,
        permit_action => {
            permit_action => 'manage_entries',
            at_least_one => 1,
        },
    },
);

sub _object_prop {
    my ( $type, $args ) = @_;

    my $prop = {
        change_draft => {
            label     => 'Change Draft Status',
            base      => '__virtual.single_select',
            display   => 'none',
            single_select_options => [
                {   label => MT->translate('Changing Draft'),
                    text  => 'ChangingDraft',
                    value => MT::ChangeDraft::Entry::DRAFT(),
                },
                {   label => MT->translate('Changed Backup'),
                    text  => 'ChangedBackup',
                    value => MT::ChangeDraft::Entry::BACKUP(),
                },
            ],
        },
        change_draft_control => {
            label       => 'Changing Draft',
            display     => sub { query_config(0, 'display_list_column') },
            condition   => sub {
                my $blog_id = MT->instance->param('blog_id');
                query_config($blog_id, 'enabled');
            },
            bulk_html   => sub {
                my $prop = shift;
                my ( $objs, $app ) = @_;
                my @rows;

                my $user = $app->user;
                my $is_relative
                    = ( $app->user->date_format || 'relative' ) eq
                    'relative' ? 1 : 0;
                my $now = time;
                my $date_format = MT::App::CMS::LISTING_DATE_FORMAT();
                my $static_path = MT->static_path;

                # 下書きとバックアップの集計 - フィルタを追加後表示
                # my @ids = map { $_->id } @$objs;
                # my @drafts = MT->model('entry')->load({id => \@ids});
                # my %draft_count;
                # foreach my $draft ( @drafts ) {
                #     my $status = $obj->change_draft_status;
                #     my $hash = $draft_count->{$status} ||= {};
                #     my $array = $hash->{$obj->change_draft_entry_id} ||= [];
                #     push @$array, $draft;
                # }

                foreach my $obj ( @$objs ) {
                    my $status = $obj->change_draft;

                    my @partials;
                    if ( $status ) {
                        push @partials, format_acted_on(
                            $obj->change_draft_branched_on,
                            user => $user,
                            blog => $obj->blog,
                            is_relative => $is_relative,
                            time => $now,
                            date_format => $date_format,
                        );
                    } else {
                        if ( $obj->change_draft_copiable ) {
                            my $uri = $app->uri(
                                mode => 'change_draft_copy',
                                args => {
                                    blog_id => $obj->blog_id,
                                    id => $obj->id,
                                }
                            );
                            my $label = plugin->translate('Create');
                            my $h = qq{
                                <img src="${static_path}images/nav_icons/color/trackbacks.gif" alt="create">
                                <a href="${uri}">${label}</a>
                            };
                            push @partials, $h;
                        }
                    }

                    push @rows, join(' ' , @partials);
                }

                @rows;
            },
            col_class   => 'num',
            order       => 250,
        },
    };

    if ( $type eq 'entry' ) {
        my $entry_props = MT::Entry->list_props;
        my $orig = $entry_props->{title}->{html};

        $prop->{title} = {
            html => sub {
                my $text = $orig->(@_);
                my $prop        = shift;
                my ($obj)       = @_;

                return $text unless $obj->change_draft;

                if ( $obj->change_draft ) {
                    my $target = $obj->change_draft_entry;
                    my $sub_label;
                    my $uri = MT->instance->uri(
                        mode => 'edit',
                        args => {
                            _type => $obj->class,
                            id => $target->id,
                            blog_id => $target->blog_id,
                        },
                    );
                    my $link = plugin->translate('<a href="[_1]">[_2]</a>', $uri, $target->title);

                    if ( $obj->change_draft_is_draft ) {
                        $sub_label = plugin->translate('Changing Draft of "[_1]"', $link);
                        $text =~ s!status_icons/draft.gif!nav_icons/color/trackbacks.gif!;
                    } elsif ( $obj->change_draft_is_backup ) {
                        my $target = $obj->change_draft_entry;
                        $sub_label = plugin->translate('Changed Backup of "[_1]"', $link);
                        $text =~ s!status_icons/draft.gif!nav_icons/color/delete.gif!;
                    }
                    $text =~ s!<span class="title">!<span class="title"><small>$sub_label:</small> ! if $sub_label;
                }

                $text;
            },
        };
    }

    $prop;
}

sub properties {
    my %props = map {
        $_ => _object_prop($_, $objects{$_})
    } keys %objects;

    \%props;
}

sub _object_action {
    my ( $type, $args ) = @_;

    {
        new_change_draft => {
            label => 'New Changing Draft',
            order => 3000,
            code => $args->{code},
            permit_action => $args->{permit_action},
            condition   => sub {
                my $blog_id = MT->instance->param('blog_id');
                query_config($blog_id, 'enabled');
            },
        },
    }
}

sub actions {
    my %actions = map {
        $_ => _object_action($_, $objects{$_})
    } keys %objects;

    \%actions;
}

sub _is_user_editable_object {
    my ( $user, $type, $obj ) = @_;
    return 1 if $user->is_superuser;

    my @blog_ids = $obj->can('blog_id') ? (0, $obj->blog_id) : (0);
    my $permit_action = $objects{$type}->{permit_action};

    $user->can_do($permit_action, at_least_one => 1, blog_id => \@blog_ids);
}

sub _return_list_action {
    my ( $app, $xhr, %opts ) = @_;
    if ( my $return_args = $opts{return_args} ) {
        $app->add_return_arg( %$return_args );
    }
    return $xhr
        ? {
            messages => [
                {
                    cls => $opts{cls},
                    msg => $opts{msg},
                }
            ]
        }
        : $app->call_return;
}

sub _action_new_change_draft {
    my $type = shift;
    my $object = $objects{$type};

    my $app = shift;
    $app->validate_magic or return;
    my $user = $app->user;

    my $xhr = $app->param('xhr');
    my @id = $app->param('id');
    @id = (0) unless @id;

    my @objects = MT->model($type)->load({id => \@id});
    my $set_count = 0;
    foreach my $obj ( @objects ) {
        next unless _is_user_editable_object($user, $type, $obj);
        next unless $obj->change_draft_copiable;
        $obj->change_draft_make_copy() or next;
        $set_count ++;
    }

    _return_list_action( $app, $xhr,
        return_args => {
            change_draft_created => 1,
            change_draft_count => $set_count,
        },
        cls => 'success',
        msg => plugin->translate(
            'Successfully create Changing draft of [_1] object(s).',
            $set_count
        ),
    );
}

sub action_new_entry_change_draft {
    _action_new_change_draft('entry', @_);
}

sub action_new_page_change_draft {
    _action_new_change_draft('page', @_);
}

sub template_param_list_common {
    my ( $cb, $app, $param, $tmpl ) = @_;

    return 1 unless $param->{list_type} =~ /^(entry|page)$/;

    {
        my $include = $tmpl->getElementById('header_include');
        my $node = $tmpl->createElement('setvarblock', { name => 'system_msg', append => 1 });
        $node->innerHTML(q(
            <__trans_section component="ChangeDraft">
            <mt:if name="change_draft_created">
                <mtapp:statusmsg
                    id="edit-draft-created"
                    class="success">
                    <__trans phrase="Successfully create Changing draft of [_1] object(s)." params="<mt:var name='change_draft_count' />">
                </mtapp:statusmsg>
            </mt:if>
            </__trans_section>
        ));
        $tmpl->insertBefore($node, $include);
    }

    foreach my $key ( qw(created count) ) {
        my $p = "change_draft_$key";
        $param->{$p} = $app->param($p);
    }

    {
        my $footer = $tmpl->getElementById('footer_include');
        my $node = $tmpl->createElement('setvarblock', { name => 'jq_js_include', append => 1 });
        $node->innerHTML(<<'TMPL');
        (function($) {
            if ( !$.mtChangeDraft ) $.mtChangeDraft = {};
            $.mtChangeDraft.action = function(element) {
                var $el = $(element);
                var prompt = $el.attr('data-prompt'),
                    action = $el.attr('data-action'),
                    thisId = $el.attr('data-id');

                if ( prompt ) {
                    if ( !confirm(prompt) ) return false;
                }

                if ( action ) {
                    var $form = $el.closest('form');
                    // $form.find('input[name="action_name"]').val(action);
                    $form.find('input[name="id"]').each(function() {
                        $(this).prop('checked', $(this).val() == thisId);
                    });
                    // $form.submit();
                    doForMarked($form.attr('id'), action);
                    return false;
                }

                return true;
            };
        })(jQuery);
TMPL
        $tmpl->insertBefore($node, $footer);
    }

    1;
}

1;