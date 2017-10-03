package MT::ChangeDraft::CMS;

use strict;
use warnings;

use MT::Util;
use MT::ChangeDraft::Util;

sub system_config_template {
    my ( $app, $param ) = @_;

    plugin->load_tmpl('system_config_template.tmpl', $param);
}

sub blog_config_template {
    my ( $plugin, $param ) = @_;
    my $app = MT->instance;

    my $config = plugin_config;
    $param->{change_draft_enabled_system_label} = $config->{change_draft_enabled}
        ? plugin->translate('Enables')
        : plugin->translate('Disables');

    $param->{change_draft_administrator} = $app->user->is_superuser;
    $param->{change_draft_system_plugin_uri} = $app->uri(
        mode => 'cfg_plugins',
        args => { blog_id => 0 },
    );

    if ( $MT::DebugMode ) {
        $param->{change_draft_debug} = 1;
        $param->{change_draft_debug_single} = query_config($param->{blog_id}, 'enabled');
        $param->{change_draft_debug_config} = query_config($param->{blog_id}, qw(enabled force_list_column widget));
    }

    plugin->load_tmpl('blog_config_template.tmpl', $param);
}

sub method_copy {
    my ( $app ) = @_;
    my $q = $app->param;
    my $blog = $app->blog
        or return $app->error(plugin->translate('No blog context.'));
    my $id = $q->param('id')
        or return $app->error(plugin->translate('No object id.'));
    my $entry = MT->model('entry')->load($id)
        or return $app->error(plugin->translate('Object not found.'));
    return $app->error(plugin->translate('This object is not copiable.'))
        unless $entry->change_draft_copiable;

    my $copy = $entry->change_draft_make_copy;

    $app->redirect(
        $app->uri( mode => 'view', args => {
            _type => $copy->class,
            blog_id => $copy->blog_id,
            id => $copy->id,
        })
    );
}

sub template_param_edit_entry {
    my ( $cb, $app, $param, $tmpl ) = @_;
    my $user = $app->user;

    my $blog_id = $param->{blog_id} or return 1;
    my $query = query_config($blog_id, qw(enabled widget));
    return 1 unless $query->{enabled};

    my $entry_id = $param->{id} or return 1;
    my $class = $param->{class} or return 1;
    my $this_entry = MT->model($class)->load($entry_id || 0) or return;
    my $blog = $this_entry->blog;

    my @change_draft_entries = grep { $_->change_draft } MT->model($class)->load({
        change_draft_entry_id => $entry_id
    }, {
        sort => 'change_draft_branched_on',
        direction => 'descend',
    });
    my $show_widget = @change_draft_entries ? 1 : 0;

    if ( $param->{change_draft_copiable} = $this_entry->change_draft_copiable ) {
        $param->{change_draft_copy_url} = $app->uri(
            mode => 'change_draft_copy',
            args => {
                blog_id => $blog->id,
                id => $entry_id,
            },
        );
        $show_widget = 1;
    }

    $param->{change_draft} = 1;

    my $is_relative
        = ( $app->user->date_format || 'relative' ) eq
        'relative' ? 1 : 0;
    my $now = time;
    my $date_format = MT::App::CMS::LISTING_DATE_FORMAT();

    if ( $this_entry->change_draft ) {
        if ( my $original = $this_entry->change_draft_entry ) {

            my $phrase;
            if ( $this_entry->change_draft ) {
              if ( $this_entry->change_draft == MT::ChangeDraft::Entry::DRAFT() ) {
                  $phrase = 'This is changing draft of <a href="[_3]">[_1] (id:[_2])</a>([_5]). When this is published, <a href="[_4]">the original page</a> will be replaced.';
              } elsif ( $this_entry->change_draft == MT::ChangeDraft::Entry::BACKUP() ) {
                  $phrase = 'This is changed backup of <a href="[_3]">[_1] (id:[_2])</a>([_5]). When this is published, <a href="[_4]">the original page</a> will be reverted.';
              }
            }

            $param->{change_draft_warning}
                = plugin->translate(
                    $phrase,
                    $original->title || plugin->translate('No Title'),
                    $original->id,
                    $this_entry->change_draft_entry_edit_url,
                    $original->permalink,
                    format_acted_on($this_entry->change_draft_branched_on, user => $user, blog => $blog),
                );
        }
    } elsif ( @change_draft_entries ) {
        $param->{change_draft_warning}
            = plugin->translate(
                'This has changing draft or changed backup. Your changes never update them.'
            );

        $param->{change_draft_entries} = [
            map {
                +{
                    status_code => $_->change_draft || MT::ChangeDraft::Entry::NONE(),
                    status      => $_->change_draft_status,
                    title       => $_->title || plugin->translate('No Title') . sprintf( ' (id:%d)', $_->id ),
                    branched_on => format_acted_on(
                        $_->change_draft_branched_on,
                        user => $user,
                        blog => $blog,
                        is_relative => $is_relative,
                        time => $now,
                        date_format => $date_format,
                    ),
                    edit_url    => $app->mt_uri(
                        mode        => 'edit',
                        args        => {
                            _type       => $_->class,
                            blog_id     => $_->blog_id,
                            id          => $_->id,
                        }
                    ),
                }
            } @change_draft_entries
        ];
    }

    {
        my $header = $tmpl->getElementById('header_include');
        my $node = $tmpl->createElement('setvarblock', { name => 'system_msg', append => 1 });
        $node->innerHTML(<<'TMPL');
            <__trans_section component="ChangeDraft">
            <mt:if name="change_draft_warning">
                <mtapp:statusmsg id="change-draft-info" class="warning">
                    <mt:Var name="change_draft_warning">
                </mtapp:statusmsg>
            </mt:if>
            </__trans_section>
TMPL
        $tmpl->insertBefore($node, $header);
    }

    if ( $show_widget ) {
        if ( $query->{widget} ) {
            my $status_widget = $tmpl->getElementById('entry-status-widget');
            my $node = $tmpl->createElement('if', { name => 'change_draft' });
            $node->innerHTML(<<'TMPL');
                <__trans_section component="ChangeDraft">
                <mtapp:widget id="change-draft-widget" label="<__trans phrase='Change Draft' />">
                    <mt:loop name="change_draft_entries">
                        <p>
                        <mt:if name="status" eq="draft">
                            <div>
                                <span class="icon status draft">
                                    <a href="<mt:var name='edit_url'>" class="icon"><img alt="Draft" src="<mt:var name="static_uri">images/nav_icons/color/trackbacks.gif"></a>
                                    <a href="<mt:var name='edit_url'>" class="title"><mt:var name="title" remove_html="1"></a>
                                </span>
                            </div>
                            <div>
                                <small>
                                    <__trans phrase="Change Draft">
                                    (<mt:var name='branched_on' />)
                                </small>
                            </div>
                        </mt:if>
                        <mt:if name="status" eq="backup">
                            <div>
                                <span class="icon status draft">
                                    <a href="<mt:var name='edit_url'>" class="icon"><img alt="Backup" src="<mt:var name="static_uri">images/nav_icons/color/delete.gif"></a>
                                    <a href="<mt:var name='edit_url'>" class="title"><mt:var name="title" remove_html="1"></a>
                                </span>
                            </div>
                            <div>
                                <small>
                                    <__trans phrase="Changed Backup">
                                    (<mt:var name='branched_on' />)
                                </small>
                            </div>
                        </mt:if>
                        </p>
                    </mt:loop>
                    <mt:if name="change_draft_copiable">
                        <mt:unless name="change_draft_entries">
                            <p><__trans phrase="You can edit and save keeping published page." /></p>
                        </mt:unless>
                        <p>
                            <div>
                                <span class="icon status draft">
                                    <a href="<mt:var name='change_draft_copy_url'>" class="icon"><img alt="Create" src="<mt:var name="static_uri">images/status_icons/create.gif"></a>
                                    <a href="<mt:var name='change_draft_copy_url'>" class="title"><__trans phrase="New Change Draft" /></a>
                                </span>
                            </div>
                        </p>
                    </mt:if>
                    <div>
                        <small><__trans phrase='<a href="http://www.ideamans.com/mt/changedraft/">About ChangeDraft</a>' /></small>
                    </div>
                </mtapp:widget>
                </__trans_section>
TMPL

            $tmpl->insertBefore($node, $status_widget);
        }
    }

    1;
}

1;
