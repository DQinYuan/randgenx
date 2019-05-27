query:
    select;

select:
    SELECT $operator AS aa
    FROM _table
    WHERE filter
    ORDER BY aa;

filter:
    _field IS NULL
|
    _field = 1.009
|
    _field >= _field
|
    _field < _field
|
    