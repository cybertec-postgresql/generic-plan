Generate a generic plan for a parameterized SQL statement
=========================================================

You can find statements with placeholders like `$1` in `pg_stat_statements`
output and the PostgreSQL log.  In many cases you don't know appropriate values
for the parameters, and even if you do, it can be cumbersome to construct an
executable statement from these parameters if there are many of them.

This extension allows you to generate a generic execution plan (one that does
not take the parameter values into account) just by feeding the parameterized
statement to the `generic_plan` function.  This is of course plain `EXPLAIN`
output, so its value for performance analysis is limited, but it is better
than nothing.

Cookbook
--------

After installing the extension, you can run

    CREATE EXTENSION IF NOT EXISTS generic_plan;

    SELECT * FROM generic_plan('SELECT * FROM tab WHERE x = $1');

Installation
------------

You can use the PostgreSQL extension infrastructure and run

    make install

after making sure that the correct `pg_config` is on your `PATH`.

Alternatively, you can copy `generic_plan.control` and the
`generic_plan--*.sql` files into the `extension` subdirectory of the PostgreSQL
"share" directory, which can be found with

    pg_ctl --sharedir

Then you can create the extension with the SQL statement

    CREATE EXTENSION generic_plan;

Installing the extension does not require superuser privileges; all you need is
the `CREATE` privilege on the target schema.

Usage
-----

The extension provides only a single function `generic_plan(text)` that takes
an SQL statement as argument.  `generic_plan(text)` is a table function, so it
should be called like this:

    SELECT plan FROM generic_plan('SELECT ...');

To get `EXPLAIN (VERBOSE)` output, call

    SELECT plan FROM generic_plan('SELECT ...', verbose => TRUE);

Similarly, cou can supply `costs => FALSE` or `settings => TRUE` to set the
corresponding `EXPLAIN` options.  If you want an output format different
from the default `TEXT`, specify `format => 'YAML'` or one of the other
formats supported by `EXPLAIN`.

Limitations
-----------

Since the extension doesn't know the parameter data types, the data types are
resolved by PostgreSQL.  This can mean that PostgreSQL chooses a different
function or operator (see [the documentation on type conversions][typeconv]).  
In the worst case, type resolution ambiguity can lead to errors.

`generic_plan` ignores string constants in the statement when searching for
parameters, but it does not consider dollar quoting or SQL comments.  If you
have something like `$42` in a comment or a dollar quoted string constant,
that will make the function fail.

 [typeconv]: https://www.postgresql.org/docs/current/typeconv.html

Support
-------

You can open a [Github issue][issue].

For commercial support, please contact
[CYBERTEC PostgreSQL International GmbH][cybertec].

 [issue]: https://github.com/cybertec-postgresql/generic-plan/issues
 [cybertec]: https://www.cybertec-postgresql.com
