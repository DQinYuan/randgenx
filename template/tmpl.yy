query:
    select ;

select:
    SELECT $operator AS aa
    FROM _table
    WHERE filter ;

filter:
    _field IS NULL
|   _field = 1.009
|   _field >= _field
|   _field < _field 
|   _field = -1
|   _field = 1
|   _field = 0
|   _field = NULL
|   _field = 4294967295
|   _field =   -2147483648
|   _field =   2147483647
|   _field =   -9223372036854775808
|   _field =   9223372036854775807
|   _field =   18446744073709551615 ;
    