package Logger;

use strict;
use warnings;

require Exporter;
our @ISA = qw/Exporter/;
our $VERSION = '0.1';
our @EXPORT;
our @EXPORT_OK = qw/get_logger/;

my (%log_levels, %def_loggers, %old_subs, %prepared_packages);

BEGIN {
	%log_levels = (
		'debug'  => -3,
		'info'   => -2,
		'notice' => -1,
		'warn'   => 0,
		'error'  => 1,
		'fatal'  => 2,
	);
}


sub get_logger {
	my %opt;
	my $caller = caller;

	if ($caller eq __PACKAGE__) {
		$caller = (caller(1))[0];
		print STDERR "getting logger for $caller (from import)\n";
	} else {
		print STDERR "getting logger for $caller\n";
	}
	if (scalar(@_) % 2) {
		%opt = ('name' => @_);
	} else {
		%opt = @_;
	}
	$opt{'package'} = $caller;

	if (exists($opt{'watch'})) {
		my $w = $opt{'watch'};

		if (ref($w) eq '' || ref($w) eq 'ARRAY') {
			_do_watch($caller, 'sub' => $w);
		} elsif (ref($w) eq 'HASH') {
			_do_watch($caller, %$w);
		}
	}

	return Logger::_log_logger->new(%opt);
}

sub watch_log {
	my $caller = caller;

	_do_watch($caller, @_);
}

sub _do_watch {
	my $forpkg = shift;
	my %opt = @_;

	no strict 'refs';
	no warnings 'redefine';

	my %subs;

	if (exists($opt{'sub'}) && defined($opt{'sub'})) {
		my @subs;
		if (ref($opt{'sub'}) eq 'ARRAY') {
			push(@subs, @{ $opt{'sub'} });
		} else {
			push(@subs, split / /, $opt{'sub'});
		}
		foreach my $sub (@subs) {
			my $pkg;
			if ($sub =~ m/^(.*)::/) {
				$pkg = $1;
				$sub = substr($sub, $+[0]);
			} else {
				$pkg = $forpkg;
			}
			push(@{ $subs{$pkg} }, $sub);
		}
	}

	if (exists($opt{'package'}) && defined($opt{'package'})) {
		my @pkgs = (ref($opt{'package'}) eq 'ARRAY') ? @{ $opt{'package'} } : (split / /, $opt{'package'});
		@pkgs = grep { $_ ne 'main' } @pkgs;

		_prepare_packages(\@pkgs);

		foreach my $pkg (@pkgs) {

			while (my $sub = each %{ "${pkg}::" }) {
				next unless ($sub =~ m/[a-z]/);
				next unless (defined &{ "${pkg}::$sub" });

				push(@{ $subs{$pkg} }, $sub);
			}
		}
	}

	while (my ($pkg, $subs) = each %subs) {

		foreach my $sub (@$subs) {

			print STDERR "Going to watch \&${pkg}::$sub\n";

			if (exists($old_subs{"${pkg}::$sub"})) {
				print STDERR "\&${pkg}::$sub is already watched\n";
				next;
			}
			unless (defined &{ "${pkg}::$sub" }) {
				print STDERR "\&${pkg}::$sub is not defined\n";
				next;
			}

			my $old_sub = \&{ "${pkg}::$sub" };

			$old_subs{"${pkg}::$sub"} = $old_sub;

			if ($pkg eq 'main') {
				*{ "${pkg}::$sub" } = sub {
					my $logger = $def_loggers{'main'};
					local $logger->[4] = \$@;
					local $logger->[5] = [];
					$@ = '';
					&$old_sub;
				};
			} else {
				*{ "${pkg}::$sub" } = sub {
					my $logger = $def_loggers{$pkg};
					local $logger->[4] = \${ "${pkg}::errstr" };
					local $logger->[5] = [];
					${ "${pkg}::errstr" } = '';
					&$old_sub;
				};
			}

			print STDERR "\&${pkg}::$sub is now watched\n";
		}
	}
}

sub _prepare_packages {
	my $pkgs = shift;

	foreach my $pkg (@$pkgs) {
		next if ($pkg eq 'main');
		next if (exists($prepared_packages{$pkg}));

		print STDERR "Creating \$${pkg}::errstr\n";

		no strict 'refs';
		${ "${pkg}::errstr" } = '';
		$prepared_packages{$pkg} = undef;
	}
}

sub import {
	my $class = shift;
	goto &get_logger;
}

{
	package Logger::_log_logger;

	use strict;
	use warnings;

	use Time::HiRes qw(gettimeofday tv_interval);

	my %log_loggers;
	my ($std_handler, $devnull_handler);


	sub new {
		my $class = shift;
		my %opt = @_;

		my $pkg = $opt{'package'};
		my $id = (exists($opt{'name'})) ? "::$opt{'name'}" : "${pkg}::";

		print STDERR "creating logger $id\n";

		if (exists($log_loggers{$id})) {
			my $self = $log_loggers{$id};
			$self->level($opt{'log_level'}) if (exists($opt{'log_level'}));
			return $self;
		}

		my $self = bless [], ref($class) || $class;
		$log_loggers{$id} = $self;
		push(@$self, $id, $pkg);

		my $lvl = (exists($opt{'log_level'}) && defined($opt{'log_level'})) ? lc($opt{'log_level'}) : 'info';
		$lvl = 'info' unless (exists($log_levels{$lvl}));

		push(@$self, $log_levels{$lvl});

		my $handler = Logger::_log_handler->new(%opt)
		or return $std_handler->error("Cannot create log handler for logger $id");

		push(@$self, [$handler]);
		push(@$self, undef, undef);

		print STDERR "setting logger as default for $pkg\n";
		$self->set_default($pkg);

		return $self;
	}

	sub level {
		my $self = shift;
		my $lvl = shift;

		if (defined($lvl) && exists($log_levels{lc($lvl)})) {
			$self->[2] = $log_levels{lc($lvl)};
			print STDERR "logger $self->[0]: level has been set to $lvl\n";
		}
		return $self;
	}

	sub set_default {
		my $self = shift;
		my $pkg = shift || caller;

		print STDERR "logger $self->[0]: Going to set me as default logger for package $pkg\n";

		if (exists($def_loggers{$pkg}) && $def_loggers{$pkg}->[0] eq $self->[0]) {
			print STDERR "logger $self->[0]: already default\n";
			return $self;
		}

		no strict 'refs';
		no warnings 'redefine';

		while (my ($level, $severity) = each %log_levels) {
			my $sub = "log_$level";
			print STDERR "logger $self->[0]: (re)defining \&${pkg}::$sub\n";
			*{ "${pkg}::$sub" } = sub {
				$self->$sub(@_);
			};
			$old_subs{"${pkg}::$sub"} = undef;
			if ($pkg eq 'main') {
				print STDERR "logger $self->[0]: (re)defining \&${pkg}::exit_$level\n";
				if ($severity > 0) {
					*{ "${pkg}::exit_$level" } = sub {
						$self->$sub(@_);
						exit 1;
					};
				} else {
					*{ "${pkg}::exit_$level" } = sub {
						$self->$sub(@_);
						exit 0;
					};
				}
				$old_subs{"${pkg}::exit_$level"} = undef;
			}
		}
		$def_loggers{$pkg} = $self;

		return $self;
	}

	sub _do_log {
		my $self = shift;
		my $log_message = shift;
	}

	sub _get_pkg {
		return $_[0]->[1];
	}

	BEGIN {
		no strict 'refs';
		no warnings 'redefine';

		while (my ($level, $severity) = each %log_levels) {
			my $sub = "log_$level";
			if ($severity > 0) {
				*{ __PACKAGE__ . "::$sub" } = sub {
					my $self = shift;

					return unless (scalar(@_));
					return unless ($self->[2] <= $severity);

					my $log_msg = {
						'level'     => $level,
						'time'      => [gettimeofday],
						'message'   => (scalar(@_) == 1) ? $_[0] : sprintf(@_),
						'callstack' => [],
					};

					if ($self->[4]) {
						push(@{ $self->[5] }, $log_msg);
						${ $self->[4] } = join("\n", map { $_->{'message'} } @{ $self->[5] });
					} else {
						$self->[3]->[-1]->$sub($log_msg);
					}

					return;
				};
			} elsif ($severity == 0) {
				*{ __PACKAGE__ . "::$sub" } = sub {
					my $self = shift;

					return 0 unless (scalar(@_));
					return 0 unless ($self->[2] <= $severity);

					my $log_msg = {
						'level'   => $level,
						'time'    => [gettimeofday],
						'message' => (scalar(@_) == 1) ? $_[0] : sprintf(@_),
					};
					$self->[3]->[-1]->$sub($log_msg);

					return 0;
				};
			} else {
				*{ __PACKAGE__ . "::$sub" } = sub {
					my $self = shift;

					return '0E0' unless (scalar(@_));
					return '0E0' unless ($self->[2] <= $severity);

					my $log_msg = {
						'level'   => $level,
						'time'    => [gettimeofday],
						'message' => (scalar(@_) == 1) ? $_[0] : sprintf(@_),
					};
					$self->[3]->[-1]->$sub($log_msg);

					return '0E0';
				};
			}
		}
	}


	package Logger::_log_handler;

	use strict;
	use warnings;

	use POSIX qw/strftime/;

	my %log_handlers;

	sub new {
		my $class = shift;
		my %opt = @_;

		my $id = (exists($opt{'log_file'})) ? "file:$opt{'log_file'}" : $std_handler->[0];

		print STDERR "creating log handler $id\n";

		if (exists($log_handlers{$id})) {
			return $log_handlers{$id};
		}

		my $self = bless [$id], ref($class) || $class;
		$log_handlers{$id} = $self;

		if (exists($opt{'log_file'})) {
			open(my $fh, '>>', $opt{'log_file'})
			or return $std_handler->error("open($opt{'log_file'}): $!");

			push(@$self, $fh);
		} else {
			return $std_handler->error("unknown id $id");
		}

		return $self;
	}


	package Logger::_stdlog_handler;

	use POSIX qw/strftime/;

	my $min_log_level;

	sub new {
		my $class = shift;

		return bless ['special:std'], ref($class) || $class;
	}

	BEGIN {
		no strict 'refs';

		$min_log_level = (sort { $a <=> $b } values %log_levels)[0];

		while (my ($level, $severity) = each %log_levels) {
			*{ __PACKAGE__ . "::log_$level" } = sub {
				my $self = shift;
				my $log_message = shift;

				my $msg = $log_message->{'message'};
				my $pre = sprintf("[%s] [%s]", strftime("%Y-%m-%d %H:%M:%S", gmtime($log_message->{'time'}->[0])), $level);
				$msg =~ s/^[\r\f\n]*|[\r\f\n]*$//gs;
				$msg =~ s/^(.*)$/$pre $1/mg;
				if ($severity > 0) {
					print STDERR $msg, "\n";
				} else {
					print STDOUT $msg, "\n";
				}

				return;
			};
		}
	}


	package Logger::_devnulllog_handler;

	sub new {
		my $class = shift;

		return bless ['special:devnull'], ref($class) || $class;
	}

	BEGIN {
		no strict 'refs';

		while (my ($level, $severity) = each %log_levels) {
			*{ __PACKAGE__ . "::log_$level" } = sub { return; };
		}
	}
	
	package Logger::_log_handler;

	BEGIN {
		print STDERR "creating devnull log handler\n";
		$devnull_handler = Logger::_devnulllog_handler->new; # dummy handler

		print STDERR "creating std log handler\n";
		$std_handler = Logger::_stdlog_handler->new;         # handler which is assigned with stdout/stderr

		$log_handlers{ $devnull_handler->[0] } = $devnull_handler;
		$log_handlers{ $std_handler->[0] } = $std_handler;

		no strict 'refs';

		while (my ($level, $severity) = each %log_levels) {
			*{ __PACKAGE__ . "::log_$level" } = sub {
				my $self = shift;
				my $log_message = shift;

				my $msg = $log_message->{'message'};
				my $pre = sprintf("[%s] [%s]", strftime("%Y-%m-%d %H:%M:%S", gmtime($log_message->{'time'}->[0])), $level);
				$msg =~ s/^[\r\f\n]*|[\r\f\n]*$//gs;
				$msg =~ s/^(.*)$/$pre $1/mg;

				print {$self->[1]} $msg, "\n";

				return;
			};
		}
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

  watch_log('sub' => 'my_sub'); # alter subroutine my_sub
                                # to set $! instead of logging

  my_sub()
  or exit_fatal("my_sub: $!");

  log_warn('2x2 != 4') unless (2 * 2 == 4);

  # in your classes
  package Foo;

  use Logger;

=cut


