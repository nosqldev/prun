#!/usr/bin/perl -w

# © Copyright 2014 jingmi. All Rights Reserved.
#
# +-----------------------------------------------------------------------+
# | test prun.pm                                                          |
# +-----------------------------------------------------------------------+
# | Author: jingmi@gmail.com                                              |
# +-----------------------------------------------------------------------+
# | Created: 2014-10-28 22:05                                             |
# +-----------------------------------------------------------------------+

use strict;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin";
use prun;
use Term::ANSIColor;

sub assert
{
    my $evaluation = shift;
    my $mesg = shift || "";

    if ($evaluation)
    {
        print color("bright_green") . "." . color("reset");
    }
    else
    {
        print color("red") . "[failed]\t" . $mesg . color("reset") . "\n";
        exit(-1);
    }
}

sub generate_string
{
    my $payloads_ref = shift;
    my $worker_id = shift;
    my $content = '';

    map { $content .= $worker_id } (1 ... $payloads_ref->[0]);

    return &child_return(\$content);
}

sub merge_string
{
    my $result_ref = shift;
    my $results_ref = shift;

    $$results_ref = join('', sort(split//, $$results_ref . $$result_ref));
}

sub main
{
    my $result_str = '';
    &prun(4, \&generate_string, [[2], [3], [1], [2],], \&merge_string, \$result_str);

    &assert($result_str eq '11222344');

    my $range_ref = &split_payload_range(2, [10, 20]);
    assert($range_ref->[0][0] == 10);
    assert($range_ref->[0][1] == 14);
    assert($range_ref->[1][0] == 15);
    assert($range_ref->[1][1] == 20);

    $range_ref = &split_payload_range(100, [10, 20]);
    assert(@$range_ref == 10);
    assert($range_ref->[0][0] == 10);
    assert($range_ref->[0][1] == 10);
    assert($range_ref->[9][0] == 19);
    assert($range_ref->[9][1] == 20);

    print color("bright_green") . "passed\n" . color("reset");
}

&main();

__END__
# vim: set expandtab tabstop=4 shiftwidth=4 foldmethod=marker:
