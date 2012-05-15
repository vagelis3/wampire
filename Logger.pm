package Logger;

use strict;
use warnings;

require Exporter;
our @ISA = qw/Exporter/;
our $VERSION = '0.1';
our @EXPORT;
our @EXPORT_OK = qw/get_logger/;

my (%log_handlers, %log_nodes);


sub get_logger {
	my %opt;
	my $caller = caller;

	if ($caller eq 'main') {
		if (scalar(@_) % 2) {
			%opt = ('name' => @_);
		} else {
			%opt = @_;
		}
	} else {
		if (scalar(@_) % 2) {
			%opt = (@_ => undef);
		} else {
			%opt = @_;
		}
	}
	$opt{'package'} = $caller;

	return _log_handler->new(%opt);
}

sub import {
	my $logger = &get_logger;

	my $pkg = $logger->_get_pkg;
	my $symbols = $logger->_get_default_symbols;

	no strict 'refs';

	foreach my $sym (@$symbols) {
		*{ "${pkg}::$sym" } = sub {
			$logger->$sym(@_);
		};
	}
}

{
	package _log_handler;

	use strict;
	use warnings;

	use Time::HiRes qw(gettimeofday tv_interval);

	my (%log_levels, %log_handlers);
	my $_default_symbols;

	BEGIN {
		%log_levels = (
			'debug'  => -1,
			'notice' => 0,
			'info'   => 1,
			'warn'   => 2,
			'error'  => 3,
			'fatal'  => 4,
		);
		foreach my $lvl (keys %log_levels) {
			push(@$_default_symbols, $lvl);
		}
	}


	sub new {
		my $class = shift;
		my %opt = @_;

		my $pkg = $opt{'package'};
		my $id = (exists($opt{'name'})) ? "::$opt{'name'}" : "${pkg}::";

		if (exists($log_handlers{$id})) {
			return $log_handlers{$id};
		}

		my $self = bless [], ref($class) || $class;
		push(@$self, $id, $pkg);

		return $self;
	}

	sub watch {
		my $self = shift;
	}

	sub level {
	}

	sub debug {
	}

	sub notice {
	}

	sub info {
	}

	sub warn {
	}

	sub error {
	}

	sub fatal {
	}

	sub _get_default_symbols {
		return $_default_symbols;
	}
}

1;

__END__

=head1 NAME
  Logger - logging facilities

=head1 SYNOPSIS

  # in main program
  use Logger;

  my $logger = Logger::get_logger();
  $logger->level('warn');
  $logger->watch('sub' => 'my_sub'); # alter subroutine my_sub
                                     # to set $! instead of logging

  my_sub()
  or exit_fatal("my_sub: $!");

  log_warn('2x2 != 4') unless (2 * 2 == 4);

  # in your classes
  package Foo;

  use Logger;

=cut


