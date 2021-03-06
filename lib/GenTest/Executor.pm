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
# Executor代表一个数据库的客户端

package GenTest::Executor;

require Exporter;
@ISA = qw(GenTest Exporter);

@EXPORT = qw(
    EXECUTOR_ROW_COUNTS
	EXECUTOR_EXPLAIN_COUNTS
	EXECUTOR_EXPLAIN_QUERIES
	EXECUTOR_ERROR_COUNTS
);

use strict;
use Carp;
use Data::Dumper;
use GenTest;
use GenTest::Constants;

use constant EXECUTOR_DSN		=> 0;
use constant EXECUTOR_DBH		=> 1;
use constant EXECUTOR_ID		=> 2;
use constant EXECUTOR_ROW_COUNTS	=> 3;
use constant EXECUTOR_EXPLAIN_COUNTS	=> 4;
use constant EXECUTOR_EXPLAIN_QUERIES	=> 5;
use constant EXECUTOR_ERROR_COUNTS	=> 6;
use constant EXECUTOR_DEFAULT_SCHEMA => 7;
use constant EXECUTOR_SCHEMA_METADATA => 8;
use constant EXECUTOR_COLLATION_METADATA => 9;
use constant EXECUTOR_META_CACHE => 10;
use constant EXECUTOR_CHANNEL => 11;

1;


sub new {
    my $class = shift;
	
	my $executor = $class->SUPER::new({
		'dsn'	=> EXECUTOR_DSN,
		'dbh'	=> EXECUTOR_DBH,
        'channel' => EXECUTOR_CHANNEL,
	}, @_);
    
    return $executor;
}

# 新建数据库连接
sub newFromDSN {
	my ($self,$dsn,$channel) = @_;
	
	if ($dsn =~ m/^dbi:mysql:/i) {
		require GenTest::Executor::MySQL;
		return GenTest::Executor::MySQL->new(dsn => $dsn, channel => $channel);
	} elsif ($dsn =~ m/^dbi:drizzle:/i) {
		require GenTest::Executor::Drizzle;
		return GenTest::Executor::Drizzle->new(dsn => $dsn);
	} elsif ($dsn =~ m/^dbi:JDBC:.*url=jdbc:derby:/i) {
		require GenTest::Executor::JavaDB;
		return GenTest::Executor::JavaDB->new(dsn => $dsn);
	} elsif ($dsn =~ m/^dbi:Pg:/i) {
		require GenTest::Executor::Postgres;
		return GenTest::Executor::Postgres->new(dsn => $dsn);
    } elsif ($dsn =~ m/^dummy/) {
		require GenTest::Executor::Dummy;
		return GenTest::Executor::Dummy->new(dsn => $dsn);
	} else {
		say("Unsupported dsn: $dsn");
		exit(STATUS_ENVIRONMENT_FAILURE);
	}
}

sub channel {
    return $_[0]->[EXECUTOR_CHANNEL];
}

sub sendError {
    my ($self, $msg) = @_;
    $self->channel->send($msg);
}


sub dbh {
	return $_[0]->[EXECUTOR_DBH];
}

sub setDbh {
	$_[0]->[EXECUTOR_DBH] = $_[1];
}

sub dsn {
	return $_[0]->[EXECUTOR_DSN];
}

sub setDsn {
	$_[0]->[EXECUTOR_DSN] = $_[1];
}

sub id {
	return $_[0]->[EXECUTOR_ID];
}

sub setId {
	$_[0]->[EXECUTOR_ID] = $_[1];
}

sub type {
	my ($self) = @_;
	
	if (ref($self) eq "GenTest::Executor::JavaDB") {
		return DB_JAVADB;
	} elsif (ref($self) eq "GenTest::Executor::MySQL") {
		return DB_MYSQL;
	} elsif (ref($self) eq "GenTest::Executor::Drizzle") {
		return DB_DRIZZLE;
	} elsif (ref($self) eq "GenTest::Executor::Postgres") {
		return DB_POSTGRES;
    } elsif (ref($self) eq "GenTest::Executor::Dummy") {
        if ($self->dsn =~ m/mysql/) {
            return DB_MYSQL;
        } elsif ($self->dsn =~ m/postgres/) {
            return DB_POSTGRES;
        } if ($self->dsn =~ m/javadb/) {
            return DB_JAVADB;
        } else {
            return DB_DUMMY;
        }
	} else {
		return DB_UNKNOWN;
	}
}

my @dbid = ("Unknown","Dummy", "MySQL","Postgres","JavaDB","Drizzle");

sub getName {
    my ($self) = @_;
    return $dbid[$self->type()];
}

sub preprocess {
    my ($self, $query) = @_;

    my $id = $dbid[$self->type()];
    
    # Keep if match (+)

    # print "... $id before: $query \n";
    
    # 看起来像是在替换掉sql中的注释
    $query =~ s/\/\*\+[a-z:]*$id[a-z:]*:([^*]*)\*\//$1/gi;

    # print "... after: $query \n";

    return $query;
}

## This array maps SQL State class (2 first letters) to a status. This
## list needs to be extended
my %class2status = (
    "07" => STATUS_SEMANTIC_ERROR, # dynamic SQL error
    "08" => STATUS_SEMANTIC_ERROR, # connection exception
    "22" => STATUS_SEMANTIC_ERROR, # data exception
    "23" => STATUS_SEMANTIC_ERROR, # integrity constraint violation
    "25" => STATUS_TRANSACTION_ERROR, # invalid transaction state
    "42" => STATUS_SYNTAX_ERROR    # syntax error or access rule
                                   # violation
    
    );

sub findStatus {
    my ($self, $state) = @_;

    my $class = substr($state, 0, 2);
    if (defined $class2status{$class}) {
        return $class2status{$class};
    } else {
        return STATUS_UNKNOWN_ERROR;
    }
}

sub defaultSchema {
    my ($self, $schema) = @_;
    if (defined $schema) {
        $self->[EXECUTOR_DEFAULT_SCHEMA] = $schema;
    }
    return $self->[EXECUTOR_DEFAULT_SCHEMA];
}

sub currentSchema {
    croak "currentSchema not defined for ". (ref $_[0]);
}


sub getSchemaMetaData {
    croak "getSchemaMetaData not defined for ". (ref $_[0]);
}

sub getCollationMetaData {
    carp "getCollationMetaData not defined for ". (ref $_[0]);
    return [[undef,undef]];
}


########### Metadata routines

sub cacheMetaData {
    my ($self) = @_;
    
    say ("Caching metadata for ".$self->dsn());

    my $meta = {};
    foreach my $row (@{$self->getSchemaMetaData()}) {
        # Meta信息的五元组格式
        my ($schema, $table, $type, $col, $key) = @$row;
        $meta->{$schema}={} if not exists $meta->{$schema};
        $meta->{$schema}->{$table}={} if not exists $meta->{$schema}->{$table};
        $meta->{$schema}->{$table}->{$col}=$key;
    }

    $self->[EXECUTOR_SCHEMA_METADATA] = $meta;

    my $coll = {};
    foreach my $row (@{$self->getCollationMetaData()}) {
        my ($collation, $charset) = @$row;
        $coll->{$collation} = $charset;
    }
    $self->[EXECUTOR_COLLATION_METADATA] = $coll;

    $self->[EXECUTOR_META_CACHE] = {};
}

sub metaSchemas {
    my ($self) = @_;
    if (not defined $self->[EXECUTOR_META_CACHE]->{SCHEMAS}) {
        my $schemas = [sort keys %{$self->[EXECUTOR_SCHEMA_METADATA]}];
        croak "No schemas found" 
            if not defined $schemas or $#$schemas < 0;
        $self->[EXECUTOR_META_CACHE]->{SCHEMAS} = $schemas;
    }
    return $self->[EXECUTOR_META_CACHE]->{SCHEMAS};
}

sub metaTables {
    my ($self, $schema) = @_;
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];

    $schema = $self->defaultSchema if not defined $schema;

    my $cachekey = "TAB-$schema";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $tables = [sort keys %{$meta->{$schema}}];
        croak "Schema '$schema' has no tables"  
            if not defined $tables or $#$tables < 0;
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $tables;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
    
}

sub metaColumns {
    my ($self, $table, $schema) = @_;
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];
    
    $schema = $self->defaultSchema if not defined $schema;
    $table = $self->metaTables($schema)->[0] if not defined $table;
    
    my $cachekey="COL-$schema-$table";
    
    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $cols = [sort keys %{$meta->{$schema}->{$table}}];
        croak "Table '$table' in schema '$schema' has no columns"  
            if not defined $cols or $#$cols < 0;
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $cols;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}

sub metaColumnsType {
    my ($self, $type, $table, $schema) = @_;
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];
    
    $schema = $self->defaultSchema if not defined $schema;
    $table = $self->metaTables($schema)->[0] if not defined $table;
    
    my $cachekey="COL-$type-$schema-$table";
    
    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $colref = $meta->{$schema}->{$table};
        my $cols = [sort grep {$colref->{$_} eq $type} keys %$colref];
        croak "Table '$table' in schema '$schema' has no '$type' columns"  
            if not defined $cols or $#$cols < 0;
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $cols;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
    
}

sub metaColumnsTypeNot {
    my ($self, $type, $table, $schema) = @_;
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];
    
    $schema = $self->defaultSchema if not defined $schema;
    $table = $self->metaTables($schema)->[0] if not defined $table;
    
    my $cachekey="COLNOT-$type-$schema-$table";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $colref = $meta->{$schema}->{$table};
        my $cols = [sort grep {$colref->{$_} ne $type} keys %$colref];
        croak "Table '$table' in schema '$schema' has no columns which are not '$type'"  
            if not defined $cols or $#$cols < 0;
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $cols;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}

sub metaCollations {
    my ($self) = @_;
    
    my $cachekey="COLLATIONS";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $coll = [sort keys %{$self->[EXECUTOR_COLLATION_METADATA]}];
        croak "No Collations defined" if not defined $coll or $#$coll < 0;
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $coll;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}

sub metaCharactersets {
    my ($self) = @_;
    
    my $cachekey="CHARSETS";
    
    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $charsets = [values %{$self->[EXECUTOR_COLLATION_METADATA]}];
        croak "No character sets defined" if not defined $charsets or $#$charsets < 0;
        my %seen = ();
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = [sort grep { ! $seen{$_} ++ } @$charsets];
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}

################### Public interface to be used from grammars
##

sub tables {
    my ($self, @args) = @_;
    return $self->metaTables(@args);
}

1;
