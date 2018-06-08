PIPADOC:MAIN:

Yet Another Implementation For Lua Strict Tables
------------------------------------------------

'tstrict' makes member definitions (in tables) mandatory. Unlike other
/strict/ modules it does not care about declarations but requires that
members are actually initialized. This eases the implementation and
(hopefully) leads to a cleaner coding style with less problematic
cases. As a side effect assigning 'nil' to a variable will undefine it
and any future use must redefine it.

Strictness checking can be disabled, Then the performance impact
should be negligible. Even with strictness checking enabled, it is
designed to have little performance impact.

All checks are have no side-effects when the program is correct and
throw an 'error()' when a violation is detected.

'tstrict' adds these forms of definitions:

VAR::
  Like normal Lua variables, once defined it can be assigned to any
  other value.

TYPED::
  Any assignment must have the same type than the current value or
  'nil' for undefining it.

CONST::
  Once defined it can not be altered. Assigning nil to undefine a
  value is is prohibited too.

CONSTRAIN::
  Associates a test function to a member which checks for validity of
  a value upon assignment.

For to enable strict checking the tstrict constructor must be applied
to a table.  This 'tstrict' constructor will add or modify the
metatable of the given table which check for validity of a value upon
assignment.

The metatable gets functions for '__index', '__newindex', '__len',
''__ipairs' and '__pairs' added.  Further it adds the control keywords
'VAR', 'TYPED', 'CONST' and 'CONSTRAIN' to the augmented table.

When tstrict is disabled, these keywords point to the table itself and
no metatable is added.

Arrays
~~~~~~

Lua handles table members indexed by integers somewhat
special. Internally tables have a 'array' part which handles all
values indexed continuously starting from 1. When indexing is sparse
values are stored in the 'hash' part of the table.

Mixing such continuous and sparse indexes is not a problem for Lua, but
iterating with 'ipairs()' and the length operator ('#') only handle
the continuous part of the array. Moreover using the '#' operator is
undefined when the integer index becomes sparse.

'tstrict' add the limitation on members indexed by integers that they
all must be from the same kind of definition ('VAR', 'TYPED', 'CONST',
or 'CONSTRAIN'). The array indices are tracked. Using the length
operator on a sparse array will raise an error.

Note that once the indices become sparse, this state is kept until
/all/ integer indices are erased. Starting over with new indices
may even choose a different kind of definitions.

This tracking only works when the indices are defined as 'TYPED',
'CONST', or 'CONSTRAIN' but not on 'VAR'. Thus 'VAR' definitions
should be avoided when using sparse arrays.


Usage
~~~~~

The canonical usage looks like (including examples for failure):

 DEBUG = true
 local strict, var, typed, const, constrain = require "tstrict" (DEBUG)

 strict (_G)

 global_x = "foobar" --> FAIL, not defined

 VAR.global_x = 10
 CONST.global_y = 20
 TYPED.global_z = 30
 print(global_x, global_y, global_z) --> 10 20 30

 global_x = "foo"  --> OK
 global_y = "bar"  --> FAIL, constant value
 global_z = "baz"  --> FAIL, type error

 local my = strict {}
 my.VAR.local_x = 40
 my.CONST.local_y = 50
 my.TYPED.local_z = 60
 print(my.local_x, my.local_y, my.local_z) --> 40 50 60

 my.local_z = nil
 my.CONSTRAIN.local_z = {"foo", function (x) return x:match("^...$" end)}
 my.local_z = "baz"  --> OK, matches constraint
 my.local_z = "barf" --> FAIL, constraint error

The tstrict module returns a function which takes one boolean argument
to enable/disable the checking. This function in turn returns a list
of functions.

First 'strict(table[, default [, constraint_function])', the generic
strictness function which augments the given table with strictness
checking. 'default' can be 'TYPED', 'CONST' or 'CONSTRAIN' and applies
to existing members in the table. When 'CONSTRAIN' is chosen, a
'constraint_function' must be given. This function then applies to all
static initialized members.

Following in the list are functions for 'var', 'typed', 'const',
'constrain' which are shorthand for calling the generic 'strict'.

Then strict checking is explicitly applied to the '_G' global table.

From there on global variables must be defined with 'VAR.', 'TYPED.',
'CONST.' or 'CONSTRAIN.' prefixes. after definition they can be used
as any other variable as long the constraints are not violated. Note
that variables *must* be initialized.  Redefining a variable without
erasing it first yields an error.

'tstrict' only applies to tables, due to Lua limitations it can not
check single local assignment. To facilitate strict checking on local
variables these need to be table members as shown with the 'local my =
strict {}' idiom.

Finally the example shows how to use undefine a variable and then
define it anew with 'CONSTRAIN' function. Such an definition takes a
{value, func(value, key, table)} pair as parameter and must return 'true'
when a values is accepted..

