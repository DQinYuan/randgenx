# Copyright (C) 2008 Sun Microsystems, Inc. All rights reserved.
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

#
# This grammar is suitable for general stress testing of storage engines
# including the InnoDB plugin and Falcon, their locking and transactional mechanisms. It can
# also be used along with the Combinations facility in order to provide stress testing under
# various configurations
#
# The goal is to spend as much time as possible inside the storage engine and as little time
# as possible in the optimizer. Therefore, most of the queries have trivial optimizer plans
# and run very quickly. 
#
# At the same time, please note that this grammar does not aim to cover all possible
# table access methods. The grammars from conf/optimizer* are more suitable for that.
#

query:
	transaction |
	select | select | select |
	select | select | select |
	insert_replace | update | delete ;

transaction:
	START TRANSACTION |
	COMMIT | ROLLBACK |
	SELECT SLEEP( zero_one ) |
	SAVEPOINT A | ROLLBACK TO SAVEPOINT A |
	SET AUTOCOMMIT=OFF | SET AUTOCOMMIT=ON |
	SET TRANSACTION ISOLATION LEVEL isolation_level;

isolation_level:
	READ UNCOMMITTED | READ COMMITTED | REPEATABLE READ | SERIALIZABLE ;

select:
	SELECT select_list FROM join_list where LIMIT large_digit for_update_lock_in_share_mode;

select_list:
	X . _field_key | X . _field_key |
	X . `pk` |
	X . _field |
	* |
	( subselect );

subselect:
	SELECT _field_key FROM _table WHERE `pk` = value ;

# Use index for all joins
join_list:
	_table AS X | 
	_table AS X LEFT JOIN _table AS Y USING ( _field_key );

for_update_lock_in_share_mode:
	| | | | | 
#	FOR UPDATE |		# bug 46539
	LOCK IN SHARE MODE ;

# Insert more than we delete
insert_replace:
	i_r ignore INTO _table (`pk`) VALUES (NULL) |
	i_r ignore INTO _table ( _field_no_pk , _field_no_pk ) VALUES ( value , value ) , ( value , value ) ;
#|
#	i_r ignore INTO _table ( _field_no_pk ) SELECT X . _field_key FROM join_list where order_by LIMIT large_digit;	# bug46650

i_r:
	INSERT | REPLACE ;

ignore:
	;
#	IGNORE # bug 46539

update:
	UPDATE ignore _table AS X SET _field_no_pk = value where LIMIT large_digit ;

# We use a smaller limit on DELETE so that we delete less than we insert

delete:
	DELETE FROM _table where_delete order_by_delete LIMIT small_digit ;

order_by:
	| ORDER BY X . _field_key ;

order_by_delete:
	| ORDER BY _field_key ;

# Use an index at all times
where:
	WHERE X . _field_key < value | 	# Use only < to reduce deadlocks
	WHERE X . _field_key IN ( value , value , value ) |
	WHERE X . _field_key BETWEEN small_digit AND large_digit ;
# |
#	WHERE X . _field_key = ( subselect ) ;

where_delete:
	|
	WHERE _field_key = value |
	WHERE _field_key IN ( value , value , value ) |
	WHERE _field_key IN ( subselect ) |
	WHERE _field_key BETWEEN small_digit AND large_digit ;

large_digit:
	5 | 6 | 7 | 8 ;

small_digit:
	1 | 2 | 3 | 4 ;

value:
	_digit | _tinyint_unsigned | _varchar(1);

zero_one:
	0 | 0 | 1;
