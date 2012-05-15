package Confile;

use strict;
use warnings;

use FindBin qw();
use File::Spec qw();
use Cwd qw();
use YAML::XS qw();

my @CINC;

BEGIN {
	@CINC = ($FindBin::Bin, @INC, Cwd::getcwd);
}


sub load_file {
	my $file = shift;

	my $path = find_file($file)
	or return;

	return YAML::XS::LoadFile($path);
}

sub process_conf {
	my @conf;

	foreach my $new_conf (@_) {
		next unless (defined($new_conf));
		push(@conf, (ref($new_conf)) ? $new_conf : load_file($new_conf));
	}

	return merge_conf(@conf);
}

sub merge_conf {
	my @conf = @_;

	my %container;
	my $result;

	foreach my $conf (@conf) {
		next unless (defined($conf));

		my $path = '';
		my $c = (ref($conf) eq '') ? 0 : (ref($conf) eq 'ARRAY') ? 1 : 2;

		if (defined($result)) {
			unless ($container{$path} == $c) {
				return $result;
			}
		} else {
			$result = ($c == 0) ? $conf : ($c == 1) ? [] : {};
			$container{$path} = $c;
		}

		next unless ($c);

		my (@s, @path);
		my $p = [$c, $conf, 0];
		if ($c == 1) {
			push(@$p, scalar(@$conf), $result);
		} else {
			push(@$p, scalar(keys %$conf), $result, [ keys %$conf ]);
		}

		while (scalar(@s) || $p->[2] < $p->[3]) {
			unless ($p->[2] < $p->[3]) {
				pop @path;
				$p = pop @s;
				$p->[2]++;
				next;
			}

			my $el = ($p->[0] == 1) ? $p->[1]->[ $p->[2] ] : $p->[1]->{ $p->[5]->[ $p->[2] ] };
			$path = join('|', @path, ($p->[0] == 1) ? $p->[2] : "'@{[ $p->[5]->[ $p->[2] ] ]}'");
			$c = (ref($el) eq '') ? 0 : (ref($el) eq 'ARRAY') ? 1 : 2;

			my $ref;
			if (exists($container{$path})) {
				unless ($container{$path} == $c) {
					$p->[2]++;
					next;
				}
				$ref = ($p->[0] == 1) ? \$p->[4]->[ $p->[2] ] : \$p->[4]->{ $p->[5]->[ $p->[2] ] };
				$$ref = $el unless ($c);
				$ref = $$ref;
			} else {
				$container{$path} = $c;
				if ($p->[0] == 1) {
					$ref = $p->[4]->[ $p->[2] ] = ($c == 0) ? $el : ($c == 1) ? [] : {};
				} else {
					$ref = $p->[4]->{ $p->[5]->[ $p->[2] ] } = ($c == 0) ? $el : ($c == 1) ? [] : {};
				}
			}
			unless ($c) {
				$p->[2]++;
				next;
			}
			push(@s, $p);
			push(@path, ($p->[0] == 1) ? $p->[2] : "'@{[ $p->[5]->[ $p->[2] ] ]}'");
			if ($c == 1) {
				$p = [$c, $el, 0, scalar(@$el), $ref];
			} else {
				$p = [$c, $el, 0, scalar(keys %$el), $ref, [ keys %$el ]];
			}
		}
	}

	return $result;
}

sub find_file {
	my $file = shift;

	foreach my $dir (@CINC) {
		my $path = File::Spec->rel2abs($file, $dir);

		return $path if (-f $path);
	}
	return;
}

sub get_dir {
	my $dir = shift;

	foreach my $root (@CINC) {
		my $path = File::Spec->rel2abs($dir, $root);

		return $path if (-d $path);
	}
	my $path = File::Spec->rel2abs($dir, $CINC[0]);
	File::Path::make_path($path);

	return $path;
}

1;

