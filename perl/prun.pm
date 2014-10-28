# © Copyright 2014 jingmi. All Rights Reserved.
#
# +-----------------------------------------------------------------------+
# | prun pm                                                               |
# +-----------------------------------------------------------------------+
# | Author: jingmi@gmail.com                                              |
# +-----------------------------------------------------------------------+
# | Created: 2014-10-28 22:03                                             |
# +-----------------------------------------------------------------------+

package prun;

require Exporter;
use strict;
use IO::Select;
use POSIX ":sys_wait_h";

our @ISA = qw/Exporter/;
our @EXPORT = qw/prun child_return split_payload_range/;

sub kill_myself
{
    chomp(my $mesg = shift);

    print STDERR $mesg, "\n";

    kill('KILL', getppid());
}

sub child_return
{
    my $string_ref = shift;

    return sprintf("%10d", length($$string_ref)), $string_ref;
}

sub split_payload_range
{
    my $process_cnt = shift;
    my $range_ref = shift;

    $process_cnt = $range_ref->[1] - $range_ref->[0] if ($range_ref->[1] - $range_ref->[0] < $process_cnt);

    my $step = int(($range_ref->[1] - $range_ref->[0]) / $process_cnt);

    my $start = $range_ref->[0];
    my @payloads_range = ();
    for my $i (1...$process_cnt)
    {
        if ($i == $process_cnt)
        {
            push(@payloads_range, [$start, $range_ref->[1]]);
        }
        else
        {
            push(@payloads_range, [$start, $start+$step-1]);
        }
        $start = $start + $step;
    }

    return \@payloads_range;
}

sub prun
{
    my $process_cnt = shift;
    my $do_func = shift;
    my $payloads_ref = shift;
    my $merge_func = shift || undef;
    my $results_ref = shift || undef;

    my $share_payloads_area;
    my @read_fd_array = ();
    my @child_pids = ();

    die ("args are incorrect\n") if ($process_cnt != scalar(@$payloads_ref));

    for my $i (1...$process_cnt)
    {
        my ($read_fd, $write_fd) = (undef, undef);
        pipe($read_fd, $write_fd);  # check return value here
        push(@read_fd_array, $read_fd);

        $share_payloads_area = $payloads_ref->[$i-1];

        my $pid = fork;
        if ($pid)
        {
            # parrent
            select(undef, undef, undef, 0.1); # to make sure that child will run first
            push(@child_pids, $pid);
        }
        else
        {
            # child
            my ($len, $content_ref) = &$do_func($share_payloads_area, $i);
            my $l = sprintf("%10d", $len);
            syswrite($write_fd, $l, length($l)); # length($l) == 10
            syswrite($write_fd, $$content_ref, $len); # check return value for all syswrite() /sysread()
            exit(0);
        }
    }

    my $s = IO::Select->new(@read_fd_array);
    my @ready_fds;

    while (@ready_fds = $s->can_read)
    {
        foreach my $fd (@ready_fds)
        {
            my $len;
            sysread($fd, $len, 10);

            my $content;
            sysread($fd, $content, int($len));
            $s->remove($fd);
            &$merge_func(\$content, $results_ref) if defined($merge_func);
        }
    }

    map { waitpid($_, WNOHANG) } @child_pids;
}

1;
