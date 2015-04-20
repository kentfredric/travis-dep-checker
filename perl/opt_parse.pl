#!/usr/bin/env perl
# ABSTRACT: Translate matrix line opts into a config file

use strict;
use warnings;

my $opts = opt->new( key => 'OPTS', );
$opts->process_opts();
$opts->check_required();
$opts->write_plconfig('./test_config.pl');
$opts->write_bashconfig('./test_config.sh');

{

    package opt;

    sub new {
        my ( $self, @args ) = @_;
        return bless { ref $args[0] ? %{ $args[0] } : @args }, $self;
    }

    sub opt_key {
        my ( $self, ) = @_;
        return ( $self->{opt_key} ||= 'OPTS' );
    }

    sub opts {
        my ( $self, ) = @_;
        my $opt_key = $self->opt_key;
        return $ENV{$opt_key} if $ENV{$opt_key};
        die "no $opt_key";
    }

    sub parsed_opts {
        my ( $self, ) = @_;
        return ( $self->{parsed_opts} ||= {} );
    }

    sub process_opts {
        my ( $self, ) = @_;
        my (@opt_list) = split /\s+/, $self->opts;
        for my $opt (@opt_list) {
            $self->handle_opt( $opt, );
        }
    }

    sub handle_opt {
        my ( $self, $opt ) = @_;
        my ( $opt_name, $opt_arg );

        if ( $opt =~ /\A([^=]+)=(.*\z)/ ) {
            $opt_name = $1;
            $opt_arg  = $2;
        }
        else {
            $opt_name = $opt;
        }
        $opt_name =~ s/-/_/g;
        my $method = 'handle_opt_' . $opt_name;
        if ( not $self->can($method) ) {
            die "Unknown option $opt_name";
        }
        return $self->$method($opt_arg);
    }

    sub handle_opt_perl {
        my ( $self, $opt_arg ) = @_;
        if ( not defined $opt_arg or not length $opt_arg ) {
            die "option perl requires an argument";
        }
        $self->parsed_opts->{'perl'} = $opt_arg;
    }

    # test_target=AUTHORID/Path-To-Dist.tar.gz
    #
    # This is the module that things are to be tested *against*
    sub handle_opt_test_target {
        my ( $self, $opt_arg ) = @_;
        if ( not defined $opt_arg or not length $opt_arg ) {
            die "option perl requires an argument";
        }
        if ( not $opt_arg =~ /\A[A-Z0-9]{2,}\/\w/ ) {
            die sprintf
              q[test_target "%s" does not match form AUTHORID/SourceFile.ext],
              $opt_arg;
        }
        if ( not $opt_arg =~ /\.(gz|bz2|tgz|zip|xz)\z/ ) {
            die q[test_target does not end with a known extension]
              . q[ ( .gz, .bz2, .tgz, .zip, .xz )];
        }
        $self->parsed_opts->{'test_target'} = $opt_arg;
    }

    # test=AUTHORID/Path-To-Dist.tar.gz
    #
    # This is the dist that will be installed and tested.
    sub handle_opt_test {
        my ( $self, $opt_arg ) = @_;
        if ( not defined $opt_arg or not length $opt_arg ) {
            die "option perl requires an argument";
        }
        if ( not $opt_arg =~ /\A[A-Z0-9]{2,}\/\w/ ) {
            die sprintf
              q[test "%s" does not match form AUTHORID/SourceFile.ext],
              $opt_arg;
        }
        if ( not $opt_arg =~ /\.(gz|bz2|tgz|zip|xz)\z/ ) {
            die q[test_target does not end with a known extension]
              . q[ ( .gz, .bz2, .tgz, .zip, .xz )];
        }
        $self->parsed_opts->{'test'} = $opt_arg;
    }

    my ($dev_targets);

    BEGIN {
        $dev_targets = {
            "test_target" => 1,
            "test"        => 1,
        };
    }

    sub set_dev {
        my ( $self, $target ) = @_;
        if ( not exists $dev_targets->{$target} ) {
            die "No such dev target $target: Valid targets are: " . join q(, ),
              keys %{$dev_targets};
        }
        $self->parsed_opts->{ 'dev_' . $target } = 1;
    }

    sub clear_dev {
        my ( $self, $target ) = @_;
        die "No such dev target $target" unless exists $dev_targets->{$target};
        delete $self->parsed_opts->{ 'dev_' . $target };
    }

    sub handle_opt_no_dev {
        my ( $self, $opt_arg ) = @_;
        my @targets;
        if ( not defined $opt_arg or not length $opt_arg ) {
            @targets = keys %{$dev_targets};
        }
        else {
            @targets = split /,/, $opt_arg;
        }
        for my $target (@targets) {
            $self->clear_dev($target);
        }
    }

    sub handle_opt_dev {
        my ( $self, $opt_arg ) = @_;
        my @targets;
        if ( not defined $opt_arg or not length $opt_arg ) {
            @targets = keys %{$dev_targets};
        }
        else {
            @targets = split /,/, $opt_arg;
        }
        for my $target (@targets) {
            $self->set_dev($target);
        }
    }

    sub check_required {
        my ($self) = @_;
        die "no test_target" unless exists $self->parsed_opts->{test_target};
        die "no test"        unless exists $self->parsed_opts->{test};
    }

    sub write_plconfig {
        my ( $self, $file ) = @_;
        require Data::Dumper;
        no warnings 'once';
        local $Data::Dumper::Terse = 1;
        local $Data::Dumper::UseQQ = 1;
        open my $fh, '>:raw:unix', $file or die "Cant open $file for writing";
        print $fh Data::Dumper::Dumper( $self->parsed_opts );
        close $fh;
    }

    sub write_bashconfig {
        my ( $self, $file ) = @_;
        open my $fh, '>:raw:unix', $file or die "Can't open $file for writing";
        for my $key ( sort keys %{ $self->parsed_opts } ) {
            my $value      = $self->parsed_opts->{$key};
            my $safe_value = $value;

            # Replace any instances of ' with '\''
            # which is the only way I know of to add a literal ' inside a '
            # because \ inside '' is meaningless.
            $safe_value =~ s/'/'\\''/g;
            printf $fh "export %s='%s'\n", $key, $safe_value;
        }
        close $fh;
    }
}
