package MT::ChangeDraft::Entry;

use strict;
use warnings;

use MT::Entry;
use MT::ChangeDraft::Util;

sub NONE { 0 }
sub DRAFT { 1 }
sub BACKUP { 2 }

sub pre_search {
    my ( $cb, $cls, $terms, $args ) = @_;

    # Hack to avoid basename check on saving page
    # Because change draft entry has same basename
    return unless ref $terms eq 'HASH';
    return unless scalar(keys %$terms) == 4;
    return unless $terms->{basename};
    return unless $terms->{blog_id};
    return unless $terms->{id};
    return unless $terms->{class} eq 'page';

    my $id = $terms->{id};
    return if ref $id;

    my $page = MT->model('page')->load($id || 0) or return;

    my %ids = ( $id => 1 );

    if ( $page->change_draft && $page->change_draft_entry_id ) {
        $ids{$page->change_draft_entry_id} = 1;
    }

    map {
        $ids{$_->id} = 1;
    } grep {
        $_->change_draft
    } MT->model('page')->load(
        { change_draft_entry_id => [ keys %ids ] },
        { fetchonly => [qw(id change_draft)] },
    );

    $terms->{id} = [ keys %ids ];

    1;
}

sub post_load {
    my ( $cb, $entry, $orig ) = @_;

    if ( $entry->change_draft ) {
        if ( my $orig = $entry->change_draft_entry ) {
            # Normalize basename to same as original
            $entry->basename($orig->basename);
        }
    }

    1;
}

sub pre_save {
    my ( $cb, $entry, $orig ) = @_;

    return 1 unless ( $entry->change_draft );

    if ( $entry->status == MT::Entry::RELEASE() ) {
        $entry->change_draft_publish or return;
    }

    1;
}

sub post_remove {
    my ( $cb, $entry, $orig ) = @_;

    unless ( $entry->change_draft ) {
        (ref $entry)->remove({ change_draft_entry_id => $entry->id });
    }

    1;
}

package MT::Entry;

use strict;
use MT::ChangeDraft::Util;


sub change_draft_is_draft {
    my $entry = shift;
    $entry->change_draft && $entry->change_draft == MT::ChangeDraft::Entry::DRAFT()? 1: 0;
}

sub change_draft_is_backup {
    my $entry = shift;
    $entry->change_draft && $entry->change_draft == MT::ChangeDraft::Entry::BACKUP()? 1: 0;
}

sub change_draft_entry {
    my $entry = shift;
    (ref $entry)->load($entry->change_draft_entry_id || 0);
}

sub change_draft_count {
    my $entry = shift;
    (ref $entry)->count({
        change_draft => MT::ChangeDraft::Entry::DRAFT(),
        change_draft_entry_id => $entry->id,
    });
}

sub change_draft_status {
    my $entry = shift;
    if ( my $status = $entry->change_draft ) {
        if ( my $orig_entry = $entry->change_draft_entry ) {
            if ( $status == MT::ChangeDraft::Entry::DRAFT() ) {
                return 'draft';
            } elsif ( $status == MT::ChangeDraft::Entry::BACKUP() ) {
                return 'backup';
            }
        }
    } else {
        if ( $entry->change_draft_count > 0 ) {
            return 'has_draft';
        } else {
            return 'normal';
        }
    }

    'unknown';
}


sub change_draft_entry_edit_url {
    my $entry = shift->change_draft_entry or return;
    my $app = MT::App::CMS->instance;

    $app->mt_uri(
        mode => 'edit',
        args => {
            _type   => $entry->class,
            blog_id => $entry->blog_id,
            id      => $entry->id,
        },
    );
}

sub change_draft_copiable {
    my $entry = shift;

    return 0 if $entry->change_draft;
    return query_config(0, 'multi_drafts')
        if $entry->change_draft_count > 0;

    1;
}

sub change_draft_make_copy {
    my $entry = shift;
    my %args = @_;
    my $entry_id = $entry->id;
    my $app = MT->instance;

    # Check if copiable
    return unless $entry->change_draft_copiable;

    # Clean up change drafts if single drafts
    unless ( query_config(0, 'multi_drafts') ) {
        my @cleanup = grep { $_->change_draft } MT->model($entry->class)->load({
            change_draft => MT::ChangeDraft::Entry::DRAFT(),
            change_draft_entry_id => $entry->id,
        });
        foreach my $c ( @cleanup ) {
            $c->remove;
        }
    }

    # Copy entry as Change Draft
    my $copy = $entry->clone;
    if ( $args{new_id} ) {
        $copy->id($args{new_id});
    } else {
        delete $copy->{column_values}->{id};
    }
    $copy->change_draft( MT::ChangeDraft::Entry::DRAFT() );
    $copy->change_draft_branched_on( $copy->blog->current_timestamp );
    $copy->status( MT::Entry::HOLD() );
    $copy->change_draft_entry_id($entry->id);

    # Reset count of comment and trackback once
    $copy->comment_count(0);
    $copy->ping_count(0);

    # Run local callback
    if ( $args{pre_save} ) {
        $args{pre_save}->($copy, $entry)
            or return $entry->error($copy->errstr);
    }

    # Run global callback
    $app->run_callbacks('change_draft_pre_save_copy', $copy, $entry)
        or return $entry->error($copy->errstr);

    $copy->save or return;

    # Copy placements
    if ( my $iter = MT->model('placement')->load_iter({ entry_id => $entry->id }) ) {
        while ( my $p = $iter->() ) {
            delete $p->{column_values}->{id};
            $p->entry_id($copy->id);
            $p->save;
        }
    }

    # Copy objecttags, objectasset
    my %tupples = (
        objecttag => {
            ds_column => 'object_datasource',
        },
        objectasset => {
            ds_column => 'object_ds',
        },
    );

    foreach my $model ( keys %tupples ) {
        my $ds_column = $tupples{$model}->{ds_column};
        my $terms = {
            $ds_column => $entry->class,
            object_id => $entry->id,
        };

        if ( my $iter = MT->model($model)->load_iter( $terms ) ) {
            while ( my $obj = $iter->() ) {
                delete $obj->{column_values}->{id};
                $obj->object_id($copy->id);
                $obj->save;
            }
        }
    }

    # Copy revisions
    if ( my $iter = $entry->revision_pkg->load_iter({ entry_id => $entry->id }) ) {
        while ( my $rev = $iter->() ) {
            delete $rev->{column_values}->{id};
            $rev->entry_id($copy->id);
            $rev->save;
        }
    }

    # Run local callback
    if ( $args{post_save} ) {
        $args{post_save}->($copy, $entry)
            or return $entry->error($copy->errstr);
    }

    # Run global callback
    $app->run_callbacks('change_draft_post_save_copy', $copy, $entry)
        or return $entry->error($copy->errstr);

    $copy;
}

sub change_draft_publish {
    my $entry = shift;
    my $app = MT->instance;

    # Down the Change Draft flag
    $entry->change_draft( MT::ChangeDraft::Entry::NONE() );

    # Backup the original
    my $backup = $entry->change_draft_entry;
    if ( $backup && $backup->change_draft != MT::ChangeDraft::Entry::BACKUP() ) {
        $backup->change_draft( MT::ChangeDraft::Entry::BACKUP() );
        $backup->change_draft_branched_on( $backup->blog->current_timestamp );
        $backup->change_draft_entry_id($entry->id);
        $backup->status( MT::Entry::HOLD() );

        # Call global callback
        $app->run_callbacks('change_draft_backup_pre_save', $backup, $entry)
            or return $entry->error($backup->errstr);

        $backup->save;

        # Move comments and trackbacks
        foreach my $model ( qw( comment trackback ) ) {
            if ( my $iter = MT->model($model)->load_iter({ entry_id => $backup->id }) ) {
                while ( my $obj = $iter->() ) {
                    $obj->entry_id($entry->id);
                    $obj->save;
                }
            }
        }

        $backup->comment_count(0);
        $backup->ping_count(0);
        $backup->save;

        # Call global callback
        $app->run_callbacks('change_draft_backup_post_save', $backup, $entry);

        # In the case of multipe drafts
        # Change parent of sibling entries
        my @entries = (ref $entry)->load({
            change_draft_entry_id => $backup->id,
        });
        foreach my $e ( @entries ) {
            next if $e->id == $entry->id;
            $e->change_draft_entry_id($entry->id);
            $e->save;
        }

        # Remove files if new entry permalink different
        if ( $entry->permalink ne $backup->permalink ) {
            $app->rebuild_entry(Entry => $backup, Blog => $backup->blog);
        }

        # Clear rebuilt cache because WeblogPublisher _rebuild_entry_archive_type watch if done by finepath.
        my $blog = $entry->blog;
        MT->instance->request( '__published:' . $blog->id, undef )
            if MT->instance->request( '__published:' . $blog->id );
    }

    1;
}

1;
