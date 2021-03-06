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

package GenTest::Simplifier::Test;

require Exporter;
use GenTest;
@ISA = qw(GenTest);

use strict;

use lib 'lib';
use GenTest::Simplifier::Tables;
use GenTest::Comparator;
use GenTest::Constants;

use constant SIMPLIFIER_EXECUTORS	=> 0;
use constant SIMPLIFIER_QUERIES		=> 1;
use constant SIMPLIFIER_RESULTS		=> 2;

my @optimizer_variables = (
	'optimizer_switch',
	'optimizer_use_mrr',
	'engine_condition_pushdown',
	'join_cache_level',
	'debug'
);

1;

sub new {
		my $class = shift;

	my $simplifier = $class->SUPER::new({
		executors	=> SIMPLIFIER_EXECUTORS,
		results		=> SIMPLIFIER_RESULTS,
		queries		=> SIMPLIFIER_QUERIES
	}, @_);

	return $simplifier;
}

sub simplify {
	my $simplifier = shift;

	my $test;

	my $executors = $simplifier->executors();

	my $results = $simplifier->results();
	my $queries = $simplifier->queries();
	my ($foo, $tcp_port) = $executors->[0]->dbh()->selectrow_array("SHOW VARIABLES LIKE 'port'");

	# If we have two Executors determine the differences in Optimizer settings and print them as test comments
	# If there is only one executor, dump its settings directly into the test as test queries

	foreach my $i (0,1) {
		if (defined $executors->[$i]) {
			my $version = $executors->[$i]->getName()." ".$executors->[$i]->version();
			$test .= "/* Server".$i.": $version */\n";
		}
	}
	$test .= "\n";


	if (defined $executors->[1] and $executors->[0]->type() == DB_MYSQL and $executors->[1]->type() == DB_MYSQL) {
		foreach my $optimizer_variable (@optimizer_variables) {
			my @optimizer_values;
			foreach my $i (0..1) {
				my $optimizer_value = $executors->[$i]->dbh()->selectrow_array('SELECT @@'.$optimizer_variable);
				$optimizer_value = 'ON' if $optimizer_value == 1 && $optimizer_variable eq 'engine_condition_pushdown';
				$optimizer_values[$i] = $optimizer_value;
			}

			if ($optimizer_values[0] ne $optimizer_values[1]) {
				$test .= "/* The value of $optimizer_variable is distinct between the two servers: */\n";
				foreach my $i (0..1) {
					if ($optimizer_values[$i] =~ m{^\d+$}) {
						$test .= "/* Server $i : SET SESSION $optimizer_variable = $optimizer_values[$i]; */\n";
					} else {
						$test .= "/* Server $i : SET SESSION $optimizer_variable = '$optimizer_values[$i]' */;\n";
					}
				}
			} else {
				$test .= "/* The value of $optimizer_variable is common between the two servers: */\n";
				$test .= "/*!50400 SET SESSION $optimizer_variable = $optimizer_values[0] */;\n";
			}

			$test .= "\n";
		}
		$test .= "\n\n";
	} elsif (defined $executors->[0]) {
		foreach my $optimizer_variable (@optimizer_variables) {
			my $optimizer_value = $executors->[0]->dbh->selectrow_array('SELECT @@'.$optimizer_variable);
			$optimizer_value = 'ON' if $optimizer_value == 1 && $optimizer_variable eq 'engine_condition_pushdown';

			if ($optimizer_value =~ m{^\d+$}) {
				$test .= "/*!50400 SET SESSION $optimizer_variable = $optimizer_value */;\n";
			} else {
				$test .= "/*!50400 SET SESSION $optimizer_variable = '$optimizer_value' */;\n";
			}
		}
		$test .= "\n\n";
	}

	my $query_count = defined $queries ? $#$queries : $#$results;

	foreach my $query_id (0..$query_count) {

		my $query;
		if (defined $queries) {
			$query = $queries->[$query_id];
		} else {
			$query = $results->[$query_id]->[0]->query();
		}

		$test .= "/* Begin test case for query $query_id */\n\n";

		my $simplified_database = 'query'.$query_id.$$;

		my $tables_simplifier = GenTest::Simplifier::Tables->new(
			dsn		=> $executors->[0]->dsn(),
			orig_database	=> 'test',
			new_database	=> $simplified_database
		);

		my @participating_tables = $tables_simplifier->simplify($query);
		
		if ($#participating_tables > -1) {
			$test .= "--disable_warnings\n";
			foreach my $tab (@participating_tables) {
				$test .= "DROP TABLE /*! IF EXISTS */ $tab;\n";
			}
			$test .= "--enable_warnings\n\n"
		}
			
		my $mysqldump_cmd = "mysqldump -uroot --extended-insert=FALSE --no-set-names --compact --force --protocol=tcp --port=$tcp_port $simplified_database ";
		$mysqldump_cmd .= join(' ', @participating_tables) if $#participating_tables > -1;
		open (MYSQLDUMP, "$mysqldump_cmd|") or say("Unable to run $mysqldump_cmd: $!");
		while (<MYSQLDUMP>) {
			next if $_=~ m{SET \@saved_cs_client}sio;
			next if $_=~ m{SET character_set_client}sio;
			$test .= $_;
		}
		close (MYSQLDUMP);

		$test .= "\n\n";

		$query =~ s{(SELECT|FROM|WHERE|GROUP\s+BY|ORDER\s+BY|HAVING|LIMIT)}{\n$1}sgio;
		$test .= $query.";\n\n";

		if (
			(defined $results) &&
			(defined $results->[$query_id])
		) {
			$test .= "/* Diff: */\n\n";

			# Add comments to each line in the diff, since MTR has issues with /* */ comment blocks.

			my $diff = GenTest::Comparator::dumpDiff(
				$simplifier->results()->[$query_id]->[0],
				$simplifier->results()->[$query_id]->[1]
			);

			$test .= "/* ".join("\n# ", split("\n", $diff))." */\n\n\n";
		}

		if ($#participating_tables > -1) {
			foreach my $tab (@participating_tables) {
				$test .= "DROP TABLE $tab;\n";
			}
		}
	
		$test .= "/* End of test case for query $query_id */\n\n";
	}

	return $test;
}

sub executors {
	return $_[0]->[SIMPLIFIER_EXECUTORS];
}

sub queries {
	return $_[0]->[SIMPLIFIER_QUERIES];
}

sub results {
	return $_[0]->[SIMPLIFIER_RESULTS];
}

1;
