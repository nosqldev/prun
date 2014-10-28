#!/usr/bin/perl -w

# © Copyright 2014 jingmi. All Rights Reserved.
#
# +-----------------------------------------------------------------------+
# | simple parallel example                                               |
# +-----------------------------------------------------------------------+
# | Author: jingmi@gmail.com                                              |
# +-----------------------------------------------------------------------+
# | Created: 2014-10-27 21:13                                             |
# +-----------------------------------------------------------------------+

use strict;
use Data::Dumper;
use IO::Select;
use POSIX ":sys_wait_h";
use Time::HiRes qw(gettimeofday tv_interval);

our $share_task = 0;

sub prun
{
    my $process_cnt = shift;
    my $do_func = shift;
    my $payloads_ref = shift;
    my $merge_func = shift;
    my $results_ref = shift || undef;

    my $share_payloads_area;
    my @read_fd_array = ();
    my @child_pids = ();

    for my $i (1...$process_cnt)
    {
        my ($read_fd, $write_fd) = (undef, undef);
        pipe($read_fd, $write_fd);
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
            my ($len, $content) = &$do_func($share_payloads_area, $i);
            my $l = sprintf("%10d", $len);
            syswrite($write_fd, $l, length($l)); # length($l) == 10
            syswrite($write_fd, $content, $len);
            exit(0);
        }
    }

    # print "--- ", scalar(@read_fd_array), " ---\n";


    my $s = IO::Select->new(@read_fd_array);
    my @ready_fds;

    my $total_elaps = 0;

    while (@ready_fds = $s->can_read)
    {
        foreach my $fd (@ready_fds)
        {
            my $begin_time = [gettimeofday];

            my $len;
            sysread($fd, $len, 10);

            my $content;
            sysread($fd, $content, int($len));
            $s->remove($fd);
            &$merge_func(\$content, $results_ref);

            $total_elaps += tv_interval($begin_time, [gettimeofday]);
        }
    }

    my $begin_time = [gettimeofday];
    map { waitpid($_, WNOHANG) } @child_pids;
    $total_elaps += tv_interval($begin_time, [gettimeofday]);

    print STDERR Dumper($total_elaps);

}

sub generate_string
{
    my $payloads_ref = shift;
    my $worker_id = shift;
    my $content = '';

    map { $content .= $worker_id } ($payloads_ref->[0] ... $payloads_ref->[1]);

    return sprintf("%10d", length($content)), $content;
}

sub print_string
{
    my $result_ref = shift;

    print $$result_ref, "\n";
}

sub find_next_prime
{
    my $start = shift;

    for (my $i=1; $i<sqrt($start)+1; $i++)
    {
        my $div = $start / $i;
        #print $start, " / ", $i, " = ", $div, "\n";
        if ($div == int($div))
        {
            $start++;
            $i = 1;
            next;
        }
    }

    return $start;
}

sub prime_worker
{
    my $payloads_ref = shift;
    my $p;
    my @primes = ();

    for (my $n=$payloads_ref->[0]; $n<$payloads_ref->[1]; $n=$p+1)
    {
        $p = &find_next_prime($n);
        push(@primes, $p);
    }

    my $content = join(",", @primes);
    return sprintf("%10d", length($content)), $content;
}

sub print_primes
{
    my $results_ref = shift;
    my $primes_ref = shift;

    my @primes = split /,/, $$results_ref;
    push(@$primes_ref, @primes);
}

sub main
{
    #&prun(2, \&generate_string, [[1, 10], [1, 5]], \&print_string);

    my @primes = ();
    &prun(8, \&prime_worker,
          [[2, 125_000], [125_001, 250_000], [250_001, 375_000], [375_001, 500_000],
           [500_001, 625_000], [625_001, 750_000], [750_001, 875_000], [875_000, 1_000_000]],
          \&print_primes, \@primes);
    my %primes = map { $_ => 1 } @primes;
    foreach my $num (sort { $a <=> $b } keys %primes)
    {
        print $num, "\n";
    }
}

&main();

__END__
# vim: set expandtab tabstop=4 shiftwidth=4 foldmethod=marker:
