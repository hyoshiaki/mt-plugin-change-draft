package MT::ChangeDraft::MT;

use strict;
use warnings;
use MT::WeblogPublisher;

sub post_init { 1 }

{
    no warnings qw( redefine );

    my $__remove_entry_archive_file = \&MT::WeblogPublisher::remove_entry_archive_file;
    *MT::WeblogPublisher::remove_entry_archive_file = sub {
        my ( $mt, %args ) = @_;
        if ( my $entry = $args{Entry} ) {
            # Skip about change draft
            return if $entry->change_draft;
        }

        $__remove_entry_archive_file->(@_);
    };

    my $__rebuild_entry = \&MT::WeblogPublisher::rebuild_entry;
    *MT::WeblogPublisher::rebuild_entry = sub {
        my ( $publisher, %args ) = @_;
        if ( ( my $entry = $args{Entry} ) && ref $args{Entry} ) {
            if ( $entry->can('change_draft') && $entry->change_draft && $entry->change_draft eq MT::ChangeDraft::Entry::DRAFT() ) {
                # reset published cache for change draft.
                my $blog = $entry->blog;
                MT->instance->request( '__published:' . $blog->id, undef )
                    if MT->instance->request( '__published:' . $blog->id );
            }
        }

        $__rebuild_entry->(@_);
    };
}

1;
