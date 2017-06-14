package App::TrimHistories;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any '$log';

our %SPEC;

$SPEC{trim_histories} = {
    v => 1.1,
    summary => 'Keep only a certain number of sets of file histories, '.
        'delete the rest',
    args => {
        files => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'file',
            schema => ['array*', of=>'filename*'],
            summary => 'Each file name must contain date',
            req => 1,
            pos => 0,
            greedy => 1,
        },
        sets => {
            schema => ['array*', of=>'int*', min_len=>2],
            default => [86400, 7, 7*86400, 4, 30*86400, 6],
        },
        discard_old_histories => {
            schema => 'bool*',
        },
        discard_young_histories => {
            schema => 'bool*',
        },
    },
    examples => [
    ],
    features => {
        dry_run => 1,
    },
};
sub trim_histories {
    require Date::Extract::PERLANCAR;
    require Algorithm::History::Levels;

    my %args = @_;

    my $parser = Date::Extract::PERLANCAR->new(format => 'epoch');

    my $files = $args{files};
    my $histories = [];
    for my $file (@$files) {
        -f $file or return [412, "$file: does not exist or not a file"];
        my $time = $parser->extract($file)
            or return [412, "$file: Can't extract date from name"];
        push @$histories, [$file, $time];
    }

    my $sets = $args{sets} // [86400, 7, 7*86400, 4, 30*86400, 6];
    @$sets > 0 && @$sets % 2 == 0
        or return [400, "Please specify an even number of elements in 'sets'"];
    my $levels = [];
    while (my ($period, $num) = splice @$sets, 0, 2) {
        push @$levels, [$period, $num];
    }

    my $res = Algorithm::History::Levels::group_histories_into_levels(
        histories => $histories,
        levels => $levels,
        discard_young_histories => $args{discard_young_histories},
        discard_old_histories => $args{discard_old_histories},
    );

    for my $f (@{ $res->{discard} }) {
        $log->infof("%sDeleting %s ...", $args{-dry_run} ? "[DRY-RUN] " : "", $f);
        unless ($args{-dry_run}) {
            unlink $f or warn "Can't delete $f: $!\n";
        }
    }

    [200, "OK"];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

See the included script L<trim-histories>.

=cut
