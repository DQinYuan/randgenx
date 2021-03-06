# Copyright (C) 2008-2010 Sun Microsystems, Inc. All rights reserved.
# Use is subject to license terms.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

package GenTest;
use base 'Exporter';
@EXPORT = ('say', 'tmpdir', 'safe_exit', 'windows', 'solaris', 'xml_timestamp', 'rqg_debug');

use strict;

use Cwd;
use POSIX;
use Carp;

my $tmpdir;

1;

sub BEGIN {
	foreach my $tmp ($ENV{TMP}, $ENV{TEMP}, $ENV{TMPDIR}, '/tmp', '/var/tmp', cwd()."/tmp" ) {
		if (
			(defined $tmp) &&
			(-e $tmp)
		) {
			$tmpdir = $tmp;
			last;
		}
	}

	if (
		($^O eq 'MSWin32') ||
		($^O eq 'MSWin64')
	) {
		$tmpdir = $tmpdir.'\\';
	} else {
		$tmpdir = $tmpdir.'/';
	}

	croak("Unable to locate suitable temporary directory.") if not defined $tmpdir;
	
	return 1;
}

our $cached_meta;

sub set_cached_meta {
    $cached_meta = @_[0];
}

sub new {
	my $class = shift;
	my $args = shift;

    # Perl面向对象的常见套路 将类名赋值给数组引用
	my $obj = bless ([], $class);

    #  scalar(@_) 获得的是参数长度
    my $max_arg = (scalar(@_) / 2) - 1;

    foreach my $i (0..$max_arg) {
		# 在循环变量i已经指定的情况下  @_代表全部的传入参数
        if (exists $args->{$_[$i * 2]}) {
		    if (defined $obj->[$args->{$_[$i * 2]}]) {
			    carp("Argument '$_[$i * 2]' passed twice to ".$class.'->new()');
		    } else {
	            $obj->[$args->{$_[$i * 2]}] = $_[$i * 2 + 1];
		    }
        } else {
				carp("Unkown argument '$_[$i * 2]' to ".$class.'->new()');
		}
	}

	return $obj;
}

sub say {
	my @t = localtime();
	my $text = shift;

	if ($text =~ m{[\r\n]}sio) {
	        foreach my $line (split (m{[\r\n]}, $text)) {
			print "# ".sprintf("%02d:%02d:%02d", $t[2], $t[1], $t[0])." $line\n";
		}
	} else {
		print "# ".sprintf("%02d:%02d:%02d", $t[2], $t[1], $t[0])." $text\n";
	}
}

sub tmpdir {
	return $tmpdir;
}

sub safe_exit {
	my $exit_status = shift;
	POSIX::_exit($exit_status);
}

sub windows {
	if (
		($^O eq 'MSWin32') ||
	        ($^O eq 'MSWin64')
	) {
		return 1;
	} else {
		return 0;
	}	
}

sub solaris {
	if ($^O eq 'solaris') {
		return 1;
	} else {
		return 0;
	}	
}

sub xml_timestamp {
	my $datetime = shift;

	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = defined $datetime ? localtime($datetime) : localtime();
	$mday++;
	$year += 1900;
	
	return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $year, $mon ,$mday ,$hour, $min, $sec);
	
}

sub rqg_debug {
	if ($ENV{RQG_DEBUG}) {
		return 1;
	} else {
		return 0;
	}
}

1;
