use strict;
use warnings;
use Cwd qw( getcwd );
use constant TRAVIS => !!( $ENV{TRAVIS} || 0 );

my $config = do "./test_config.pl";
exit 0 if not exists $config->{perl};

### WARNING BEFORE TESTING:
#
# 1. This code is not useful if your username is not "travis" and $HOME is not /home/travis
#    ( This is due to the way the brewed perls work )
#
# 2. This code will stomp into /home/travis/... perlbrew/.../someversion
#
# 3. If such a dir exists it will be **FORCIBLY** rmtreed.
#
# So be very careful when testing this outside travis and make liberal use of _TRAVIS_TEST_ROOT

my $urls = {
    https => 'https://github.com/travis-perl/builds.git',
    ssh   => 'git@github.com:travis-perl/builds.git',
};

if ( not TRAVIS ) {
    *STDERR->print(<<"EOF");
using $0 outside travis is ill advised as it needs to write to /home/travis
EOF
    exit 0;
}

my $root = $ENV{_TRAVIS_TEST_ROOT};
$root ||= '/home/travis';

my $target = "${root}/perl5/perlbrew/perls/" . $config->{perl};

## Install vendor perl to perlbrew
*STDERR->print("Installing perl $config->{perl} to $target\n");

if ( TRAVIS and -e $target and -d $target ) {
    *STDERR->print("$target exists!");
    require File::Path;
    my $err;
    my $args = {
        err     => \$err,
        safe    => 0,
        verbose => 1,
    };
    my $count = File::Path::remove_tree( $target, $args );
}
system( 'git', 'clone', '--depth=1', '--branch=perl/' . $config->{perl},
    $urls->{https}, $target );

my $child_error = $?;
my $exit        = $child_error >> 8;
my $signal      = $child_error & 127;
my $core_dumped = $child_error & 128;

if ( $exit != 0 ) {
    *STDERR->print("git failed, SIGNAL $signal EXIT $exit\n");
    *STDERR->print("core dumped\n") if $core_dumped;
    exit $exit;
}

*STDERR->print("Generating perl ENV script ./perlenv");
system( 'perlbrew env \'' . $config->{perl} . '\' > ./perlenv' );

open my $fh, '>>', './perlenv' or die "Cant open ./perlenv for writing";
$fh->print("\n\n");
$fh->print("source ~/perl5/perlbrew/etc/bashrc");
close $fh;

