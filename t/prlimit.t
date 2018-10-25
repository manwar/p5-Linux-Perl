#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use FindBin;
use lib "$FindBin::Bin/lib";
use LP_EnsureArch;

LP_EnsureArch::ensure_support('prlimit');

use Test::More;
use Test::FailWarnings -allow_deps => 1;
use Test::SharedFork;

use Linux::Perl::prlimit;

for my $generic_yn ( 0, 1 ) {
    if ( my $pid = fork ) {
        waitpid $pid, 0;
        die if $?;
    }
    else {
        eval {
            my $class = 'Linux::Perl::prlimit';
            if (!$generic_yn) {
                require Linux::Perl::ArchLoader;
                $class = Linux::Perl::ArchLoader::get_arch_module($class);
            };

            diag "class: $class";
            _do_tests($class);
        };
        die if $@;
        exit;
    }
}

done_testing();

#----------------------------------------------------------------------

sub _do_tests {
    my ($class) = @_;

    my @lims1 = $class->get(0, $class->NUMBER()->{'NPROC'});

    my @lims2 = $class->set(0, $class->NUMBER()->{'NPROC'}, 543, 654);

    is( "@lims2", "@lims1", 'set() matches prior get()' );

    my @lims3 = $class->set(0, $class->NUMBER()->{'NPROC'}, 432, 543);

    is( "@lims3", '543 654', 'set() output matches input to prior set()' );

    pipe( my $ready_r, my $ready_w );

    pipe( my $p_ready_r, my $p_ready_w );

    my $pid = fork or do {
        close $ready_r;
        close $p_ready_w;

        my @old = $class->set(0, $class->NUMBER()->{'NPROC'}, 111, 222);

        syswrite($ready_w, "@old\n");
        readline $p_ready_r;
        close $p_ready_r;

        @old = $class->get(0, $class->NUMBER()->{'NPROC'});
        syswrite($ready_w, "@old\n");

        exit;
    };

    close $ready_w;
    close $p_ready_r;

    readline $ready_r;

    my @lims4 = $class->get( $pid, $class->NUMBER()->{'NPROC'} );

    is( "@lims4", '111 222', 'read other process’s rlimit' );

    $class->set( $pid, $class->NUMBER()->{'NPROC'}, 110, 220 );

    print {$p_ready_w} "\n";
    close $p_ready_w;

    my @lims6 = split m<\s+>, readline $ready_r;
    is( "@lims6", '110 220', 'set other process’s rlimit' );

    waitpid $pid, 0;

    return;
}
