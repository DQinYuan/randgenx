# Copyright (C) 2008-2009 Sun Microsystems, Inc. All rights reserved.
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

package GenTest::Random;

require Exporter;
@ISA = qw(GenTest);
@EXPORT = qw(
	FIELD_TYPE_NUMERIC
	FIELD_TYPE_STRING
	FIELD_TYPE_DATE
	FIELD_TYPE_TIME
	FIELD_TYPE_DATETIME
	FIELD_TYPE_TIMESTAMP
	FIELD_TYPE_ENUM
	FIELD_TYPE_SET
	FIELD_TYPE_YEAR
	FIELD_TYPE_BLOB
	FIELD_TYPE_DICT
	FIELD_TYPE_DIGIT
	FIELD_TYPE_LETTER
	FIELD_TYPE_NULL
	FIELD_TYPE_ASCII
	FIELD_TYPE_EMPTY

	FIELD_TYPE_HEX
	FIELD_TYPE_QUID
);

use strict;

use GenTest;
use Cwd;

=pod

This module provides a clean interface to a pseudo-random number
generator. 

There are quite a few of them on CPAN with various interfaces, so I
decided to create a uniform interface so that the underlying
pseudo-random function or module can be changed without affecting the
rest of the software.

The important thing to note is that several pseudo-random number
generators may be active at the same time, seeded with different
values. Therefore the underlying pseudo-random function must not rely
on perlfunc's srand() and rand() because those maintain a single
system-wide pseudo-random sequence.

This module is equipped with it's own Linear Congruential Random
Number Generator, see
http://en.wikipedia.org/wiki/Linear_congruential_generator For
efficiency, math is done in integer mode

=cut

use constant RANDOM_SEED		=> 0;
use constant RANDOM_GENERATOR		=> 1;
use constant RANDOM_VARCHAR_LENGTH	=> 2;
use constant RANDOM_STRBUF          => 3;

use constant FIELD_TYPE_NUMERIC		=> 2;
use constant FIELD_TYPE_STRING		=> 3;
use constant FIELD_TYPE_DATE		=> 4;
use constant FIELD_TYPE_TIME		=> 5;
use constant FIELD_TYPE_DATETIME	=> 6;
use constant FIELD_TYPE_TIMESTAMP	=> 7;
use constant FIELD_TYPE_YEAR		=> 8;

use constant FIELD_TYPE_ENUM		=> 9;
use constant FIELD_TYPE_SET		=> 10;
use constant FIELD_TYPE_BLOB		=> 11;

use constant FIELD_TYPE_DIGIT		=> 12;
use constant FIELD_TYPE_LETTER		=> 13;
use constant FIELD_TYPE_NULL		=> 14;
use constant FIELD_TYPE_DICT		=> 15;
use constant FIELD_TYPE_ASCII		=> 16;
use constant FIELD_TYPE_EMPTY		=> 17;

use constant FIELD_TYPE_HEX		=> 18;
use constant FIELD_TYPE_QUID		=> 19;

use constant FIELD_TYPE_BIT		=> 20;

my %dict_exists;
my %dict_data;
my %data_dirs;

my %name2type = (
	'bit'			=> FIELD_TYPE_BIT,
	'bool'			=> FIELD_TYPE_NUMERIC,
	'boolean'		=> FIELD_TYPE_NUMERIC,
	'tinyint'		=> FIELD_TYPE_NUMERIC,
	'smallint'		=> FIELD_TYPE_NUMERIC,
	'mediumint'		=> FIELD_TYPE_NUMERIC,
	'int'			=> FIELD_TYPE_NUMERIC,
	'integer'		=> FIELD_TYPE_NUMERIC,
	'bigint'		=> FIELD_TYPE_NUMERIC,
	'float'			=> FIELD_TYPE_NUMERIC,
	'double'		=> FIELD_TYPE_NUMERIC,
	'double precision'	=> FIELD_TYPE_NUMERIC,
	'decimal'		=> FIELD_TYPE_NUMERIC,
	'dec'			=> FIELD_TYPE_NUMERIC,
	'numeric'		=> FIELD_TYPE_NUMERIC,
	'fixed'			=> FIELD_TYPE_NUMERIC,
	'char'			=> FIELD_TYPE_STRING,
	'varchar'		=> FIELD_TYPE_STRING,
	'binary'		=> FIELD_TYPE_BLOB,
	'varbinary'		=> FIELD_TYPE_BLOB,
	'tinyblob'		=> FIELD_TYPE_BLOB,
	'blob'			=> FIELD_TYPE_BLOB,
	'mediumblob'		=> FIELD_TYPE_BLOB,
	'longblob'		=> FIELD_TYPE_BLOB,
	'tinytext'		=> FIELD_TYPE_STRING,
	'text'			=> FIELD_TYPE_STRING,
	'mediumtext'		=> FIELD_TYPE_STRING,
	'longtext'		=> FIELD_TYPE_STRING,
	'date'			=> FIELD_TYPE_DATE,
	'time'			=> FIELD_TYPE_TIME,
	'datetime'		=> FIELD_TYPE_DATETIME,
	'timestamp'		=> FIELD_TYPE_TIMESTAMP,
	'year'			=> FIELD_TYPE_YEAR,
	'enum'			=> FIELD_TYPE_ENUM,
	'set'			=> FIELD_TYPE_SET,
	'null'			=> FIELD_TYPE_NULL,
	'letter'		=> FIELD_TYPE_LETTER,
	'digit'			=> FIELD_TYPE_DIGIT,
	'data'			=> FIELD_TYPE_BLOB,
	'ascii'			=> FIELD_TYPE_ASCII,
	'string'		=> FIELD_TYPE_STRING,
	'empty'			=> FIELD_TYPE_EMPTY,

	'hex'			=> FIELD_TYPE_HEX,
	'quid'			=> FIELD_TYPE_QUID
);

my $cwd = cwd();

# Min and max values for integer data types

my %name2range = (
	'bool'		=> [0, 1],
	'boolean'	=> [0, 1],
        'tinyint'       => [-128, 127],
        'smallint'      => [-32768, 32767],
        'mediumint'     => [-8388608, 8388607],
        'int'           => [-2147483648, 2147483647],
        'integer'       => [-2147483648, 2147483647],
        'bigint'        => [-9223372036854775808, 9223372036854775807],

        'tinyint_unsigned'      => [0, 255],
        'smallint_unsigned'     => [0, 65535],
        'mediumint_unsigned'    => [0, 16777215],
        'int_unsigned'          => [0, 4294967295],
        'integer_unsigned'      => [0, 4294967295],
        'bigint_unsigned'       => [0, 18446744073709551615]
);

my $prng_class;

1;

sub new {
    my $class = shift;

	my $prng = $class->SUPER::new({
		'seed'			=> RANDOM_SEED,
		'varchar_length'	=> RANDOM_VARCHAR_LENGTH
	}, @_ );


	$prng->setSeed($prng->seed() > 0 ? $prng->seed() : 1);

#	say("Initializing PRNG with seed '".$prng->seed()."' ...");

	$prng->[RANDOM_GENERATOR] = $prng->seed();

	return $prng;
}

sub seed {
	return $_[0]->[RANDOM_SEED];
}

sub setSeed {
	$_[0]->[RANDOM_SEED] = $_[1];
	$_[0]->[RANDOM_GENERATOR] = $_[1];
}	


### Random unsigned integer. 16 bit on 32-bit platforms, 48 bit on
### 64-bit platforms. For internal use in Random.pm. Use int() or
### uint16() instead.
sub urand {
    use integer;
    $_[0]->[RANDOM_GENERATOR] = 
        $_[0]->[RANDOM_GENERATOR] * 1103515245 + 12345;
    ## The lower bits are of bad statsictical quality in an LCG, so we
    ## just use the higher bits.
 
    ## Unfortunetaly, >> is an arithemtic shift so we shift right 15
    ## bits and have take the absoulte value off that to get a 16-bit
    ## unsigned random value.
    
    my $rand = $_[0]->[RANDOM_GENERATOR] >> 15;

    ## Can't use abs() since abs() is a function that use float (SIC!)
    if ($rand < 0) {
        return -$rand;
    } else {
        return $rand;
    }
}

### Random unsigned 16-bit integer
sub uint16 {
    use integer;
    # urand() is manually inlined for efficiency
    $_[0]->[RANDOM_GENERATOR] = 
        $_[0]->[RANDOM_GENERATOR] * 1103515245 + 12345;
    return $_[1] + 
        ((($_[0]->[RANDOM_GENERATOR] >> 15) & 0xFFFF) % ($_[2] - $_[1] + 1));
}

### Signed 64-bit integer of any range.
### Slower, so use uint16 wherever possible.
sub int {
    my $rand;
    { 
        use integer;
        # urand() is manually inlined for efficiency
        $_[0]->[RANDOM_GENERATOR] = 
            $_[0]->[RANDOM_GENERATOR] * 1103515245 + 12345;
        # Since this may be a 64-bit platform, we mask down to 16 bit
        # to ensure the division below becomes correct.
        $rand = ($_[0]->[RANDOM_GENERATOR] >> 15) & 0xFFFF;
    }
    return int($_[1] + (($rand / 0x10000) * ($_[2] - $_[1] + 1)));
}

sub digit {
	return $_[0]->uint16(0, 9);
}

sub letter {
	return $_[0]->string(1);
}

sub hex {
	my ($prng, $length) = @_;
	$length = 4 if not defined $length;
	return '0x'.join ('', map { (0..9,'A'..'F')[$prng->int(0,15)] } (1..$prng->int(1,$length)) );
}

sub date {
	my $prng = shift;
	return sprintf('%04d-%02d-%02d',
                   $prng->uint16(2000,2009),
                   $prng->uint16(1,12),
                   $prng->uint16(1,28));
}

sub year {
	my $prng = shift;
	return $prng->uint16(2000,2009);
}

sub time {
	my $prng = shift;
	return sprintf('%02d:%02d:%02d',
                   $prng->uint16(0,23),
                   $prng->uint16(0,59),
                   $prng->uint16(0,59));
}

sub datetime {
	my $prng = shift;
	return $prng->date()." ".$prng->time();
}

sub timestamp {
	my $prng = shift;
	return sprintf('%04d%02d%02d%02d%02d%02d',
                   $prng->uint16(2000,2009),
                   $prng->uint16(1,12),
                   $prng->uint16(1,28),
                   $prng->uint16(0,23),
                   $prng->uint16(0,59),
                   $prng->uint16(0,59));
}

sub enum {
	my $prng = shift;
	return $prng->letter();
}

sub set {
	my $prng = shift;
	return join(',', map { $prng->letter() } (0..$prng->digit() ) );
}

sub string {
    use constant RANDOM_STRBUF_SIZE => 1024;
    use integer;
	my ($prng, $len, $range) = @_;

	$len = 1 if not defined $len;
	$range = [97, 122] if not defined $range;
	$len = $prng->[RANDOM_VARCHAR_LENGTH] if defined $prng->[RANDOM_VARCHAR_LENGTH];
    # If the length is 0 or negative, return a zero-length string
    return '' if $len <= 0;
 
    # If the length is 1, just return one random character
	if ($len == 1) {
        return chr($prng->uint16($range->[0],$range->[1]));
	}

    # We store a random string of length RANDOM_STRBUF_SIZE which we fill with
    # random bytes. Each time a new string is requested, we shift the
    # string one byte right and generate a new string at the beginning
    # of the string.

	my $rnd;
	my ($min, $max) = ($range->[0], $range->[1]);
	my $modulus = $max - $min + 1;
    my $actual_length = $prng->uint16(1,$len);

    if (not defined $prng->[RANDOM_STRBUF]) {
        # Fill the buffer with random bytes.
        @{$prng->[RANDOM_STRBUF]} = 
            map {$prng->uint16(0,255)} (1..RANDOM_STRBUF_SIZE);
    } else {
        # Shift right and put a new byte at the front
        pop(@{$prng->[RANDOM_STRBUF]});
        unshift(@{$prng->[RANDOM_STRBUF]},$prng->uint16(0,255));
    }

    if ($actual_length <= RANDOM_STRBUF_SIZE) {
        ## If the wanted length fit in the buffer, just return a slice of it.
        return pack("c*", 
                    map {($min + ($_ % $modulus))} 
                    @{$prng->[RANDOM_STRBUF]}[1..$actual_length]);
    } else {
        ## Otherwise wil fill repeatedly from the buffer
        my $res = "";
        while ($actual_length > RANDOM_STRBUF_SIZE){
            $res .= pack("c*", 
                         map {($min + ($_ % $modulus))} 
                         @{$prng->[RANDOM_STRBUF]});
            $actual_length -= RANDOM_STRBUF_SIZE;
        }
        return $res . pack("c*", 
                           map {($min + ($_ % $modulus))} 
                           @{$prng->[RANDOM_STRBUF]}[1..$actual_length]);
    }
}

sub quid {
	my $prng = shift;
    
	return pack("c*", map {
		$prng->uint16(65,90);
                } (1..5));
}

sub bit {
	my ($prng, $length) = @_;
	$length = 1 if not defined $length;
	return 'b\''.join ('', map { $prng->int(0,1) } (1..$prng->int(1,$length)) ).'\'';
}

#
# Return a random array element from an array reference
#

sub arrayElement {
    ## To avoid mod zero-problems in uint16 (See Bug#45857)
    return undef if $#{$_[1]} < 0;
	return $_[1]->[ $_[0]->uint16(0, $#{$_[1]}) ];
}

#
# Return a random value appropriate for this type of field
#

# 各类数据随机生成规则
sub fieldType {
	my ($rand, $field_def) = @_;

	$field_def =~ s{ }{_}sio;
	$field_def =~ s{^_}{}sio;
	my ($field_base_type) = $field_def =~ m{^([A-Za-z]*)}sio;
	my ($field_full_type) = $field_def =~ m{^([A-Za-z_]*)}sio;
	my ($field_length) = $field_def =~ m{\((.*?)\)}sio;
	$field_length = 1 if not defined $field_length;
	my $field_type = $name2type{$field_base_type};

	if ($field_type == FIELD_TYPE_DIGIT) {
		return $rand->digit();
	} elsif ($field_type == FIELD_TYPE_LETTER) {
		return $rand->string(1);
	} elsif ($field_type == FIELD_TYPE_NUMERIC) {
		return $rand->int(@{$name2range{$field_full_type}});
	} elsif ($field_type == FIELD_TYPE_STRING) {
		return $rand->string($field_length);
	} elsif ($field_type == FIELD_TYPE_DATE) {
		return $rand->date();
	} elsif ($field_type == FIELD_TYPE_YEAR) {
		return $rand->year();
	} elsif ($field_type == FIELD_TYPE_TIME) {
		return $rand->time();
	} elsif ($field_type == FIELD_TYPE_DATETIME) {
		return $rand->datetime();
	} elsif ($field_type == FIELD_TYPE_TIMESTAMP) {
		return $rand->timestamp();
	} elsif ($field_type == FIELD_TYPE_ENUM) {
		return $rand->enum();
	} elsif ($field_type == FIELD_TYPE_SET) {
		return $rand->set();
	} elsif ($field_type == FIELD_TYPE_BLOB) {
		return $rand->file("$cwd/data");
	} elsif ($field_type == FIELD_TYPE_NULL) {
		return undef;
	} elsif ($field_type == FIELD_TYPE_ASCII) {
		return $rand->string($field_length, [0, 255]);
	} elsif ($field_type == FIELD_TYPE_EMPTY) {
		return '';
	} elsif ($field_type == FIELD_TYPE_HEX) {
		return $rand->hex($field_length);
	} elsif ($field_type == FIELD_TYPE_QUID) {
		return $rand->quid();
	} elsif ($field_type == FIELD_TYPE_DICT) {
		return $rand->fromDictionary($field_base_type);
	} elsif ($field_type == FIELD_TYPE_BIT) {
		return $rand->bit($field_length);
	} else {
		die ("unknown field type $field_def");
	}
}

sub file {
	my ($prng, $dir) = @_;
	if (not exists $data_dirs{$dir}) {
		my @files = <$dir/*>; 
		$data_dirs{$dir} = \@files;
	}

	return "LOAD_FILE('".$prng->arrayElement($data_dirs{$dir})."')";

}

sub isFieldType {
	my ($rand, $field_def) = @_;
	return undef if not defined $field_def;
    
	# 删去开头的_
	$field_def =~ s{^_}{}sio;
	# 获取剩下字符串中的第一个单词作为field_name
	my ($field_name) = $field_def =~ m{^([A-Za-z]*)}sio;

	if (exists $name2type{$field_name}) {
		return $name2type{$field_name};
		# 测试在dict/目录下面能不能找到相应的字典，能找到的话则将其类型设置为FIELD_TYPE_DICT
	} elsif ($rand->isDictionary($field_name)) {
		$name2type{$field_name} = FIELD_TYPE_DICT;
		return FIELD_TYPE_DICT;
	} else {
		return undef;
	}
}

sub isDictionary {
	my ($rand, $dict_name) = @_;

	if ($dict_exists{$dict_name}) {
		return 1;
	} else {
        my $dict_file = $ENV{RQG_HOME} ne '' ? $ENV{RQG_HOME}."/dict/$dict_name.txt" : "dict/$dict_name.txt";

        # -e用于测试文件是否存在
        if (-e $dict_file) {
			$dict_exists{$dict_name} = 1;
			return 1;
		} else {
			return undef;
		}
	}
}

sub fromDictionary {
	my ($rand, $dict_name) = @_;

	if (not exists $dict_data{$dict_name}) {
		my $dict_file = $ENV{RQG_HOME} ne '' ? $ENV{RQG_HOME}."/dict/$dict_name.txt" : "dict/$dict_name.txt";

		open (DICT, $dict_file) or warn "# Unable to load $dict_file: $!";
		my @dict_data = map { chop; $_ } <DICT>;
		close DICT;
		$dict_data{$dict_name} = \@dict_data;
	}

	return $rand->arrayElement($dict_data{$dict_name});
}

sub shuffleArray {
	my ($rand, $array) = @_;
	my $i;
	for ($i = @$array; --$i; ) {
	        my $j = $rand->uint16(0, $i);
	        next if $i == $j;
	        @$array[$i,$j] = @$array[$j,$i];
	}
	return $array;
}

1;
