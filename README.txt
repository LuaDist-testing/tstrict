Yet Another Implementation For Lua Strict Tables
================================================

'tstrict' enforces modes on table members. New members must be defined
with such a mode or a table can be constructed with a default
definition mode.  Assigning 'nil' to a variable will undefine it and
any future use must redefine it.

Strictness checking can be disabled, Then the performance impact
should be negligible. Even with strictness checking enabled, it is
designed to have little performance impact (depending on the mode).

All checks are have no side-effects when the program is correct and
throw an 'error()' when a violation is detected.

'tstrict' adds these modes:

VAR::
  Like normal Lua variables, once defined it can be assigned to any
  other value. Writing to undefined members will raise an error.

TYPED::
  Any assignment must have the same type than the current value.

CONST::
  Once defined it can not be altered.

CONSTRAIN::
  Associates a test function to a member which checks for validity of
  a value upon assignment.

FINAL::
  Mark tables final will lock it's contents. All attempts changing
  it (indcluding erasing memnbers) raise an error.

Strict checking is applied to tables by calling an augmenting function
from the tstrict module upon them. It is possible to change the tables
mode by apply the function again (unless the table was marked as
'final').

+tstrict.strict(table, init, default, force)+::
  +init+:::
    The definition mode for all members already existing in the table.
    it can be nil, 'TYPED', 'CONST' or a Lua function for defining a
    constraint.  'nil' means the most basic level of strictness
    checking variables must be defined with '.VAR' but no other
    restrictions are apply.

  +default+:::
    The default for new members. When 'nil' no default exists and
    members must be explicit defined. 'TYPED', 'CONST' and a lua
    function select the respective mode. 'FINAL' will reject adding
    new members to the table.

  +force+:::
    Enforces the mode given as +default+ and disables explicit definitons
    with the '.VAR', '.TYPED', '.CONST' or '.CONSTRAIN' keywords.

  Returns 'table' augmented with strict checking.

  In the simplest case, init and default are nil then strict
  checking can be added like this:

  +local my = strict {}+


+tstrict.typed(table)+::
  Equivalent to +strict(table, 'TYPED')+.
  Existing members become 'typed', new members must be explicitly
  defined.

+tstrict.const(table)+::
  Equivalent to +strict(table, 'CONST')+.
  Existing members become 'const', new members must be explicitly
  defined.

+tstrict.typed_def(table)+::
  Equivalent to +strict(table, 'TYPED', 'TYPED')+.
  Makes existing and new members 'typed' unless otherwise defined.

  TIP: this is a good starting point for augmenting tables in
  existing programs. It may catch type errors while being least
  intrusive to existing codebases.

+tstrict.const_def(table)+::
  Equivalent to +strict(table, 'CONST', 'CONST')+.
  Allows easy adding new members to a table but no mutations.

+tstrict.final(table)+::
  Equivalent to +strict(table, 'CONST', 'FINAL', true)+.
  Locks the table down, nothing can be changed. A good choice for
  module interfaces.

For to add strict checking to a table the tstrict constructor must be
applied to a table.  This 'tstrict' constructor will add or modify the
metatable of the given table which check for validity of a value upon
assignment.

The metatable gets functions for '__index', '__newindex', '__len',
''__ipairs' and '__pairs' added.  Further it adds the definiton keywords
'VAR', 'TYPED', 'CONST' and 'CONSTRAIN' to the augmented table.

When tstrict is disabled, the definition keywords point to the table
itself and no metatable is added.

Sequences
~~~~~~~~~

Lua handles table members indexed by integers somewhat
special. Internally tables have a 'array' part which handles all
values indexed continuously starting from 1. When indexing becomes
sparse values are stored in the 'hash' part of the table.

Mixing such continuous and sparse indexes is not a problem for Lua,
but iterating with 'ipairs()' and the length operator # only handle
the continuous part of the array. Moreover using the # operator is
undefined when the integer index becomes sparse.

'tstrict' add the limitation on members indexed by integers that they
all must be from the same mode of definition ('VAR', 'TYPED', 'CONST',
or 'CONSTRAIN'). The array indices are tracked. Using the length
operator on a sparse array will raise an error.

Note that once the indices become sparse there is no way back to
making it continous again.


Example Usage
~~~~~~~~~~~~~

The canonical usage looks like (including examples for failure):

----
-- 1.
local DEBUG = true
local tstrict = require "tstrict" (DEBUG)

local strict, typed, const, typed_def, const_def, final
       = tstrict.strict, tstrict.typed, tstrict.const,
         tstrict.typed_def, tstrict.const_def, tstrict.final

-- 2.
strict (_G)

-- 3.
x = "foobar" --> FAIL, not defined

VAR.x = 10
CONST.y = 20
TYPED.z = 30
print(x, y, z) --> 10 20 30

x = "foo"  --> OK
y = "bar"  --> FAIL, constant value
z = "baz"  --> FAIL, type error

-- 4.
VAR.x = 10  --> OK, redefiniton with same value
VAR.x = 11  --> FAIL, already defined

-- 5.
local my = strict {}
my.VAR.x = 40
my.CONST.y = 50
my.TYPED.z = 60
print(my.x, my.y, my.z) --> 40 50 60

-- 6.
my.z = nil
my.CONSTRAIN.z = {"foo", function (x) return x:match("^...$" end)}
my.z = "baz"  --> OK, matches constraint
my.z = "barf" --> FAIL, constraint error
----

1. The tstrict module returns a function which takes one boolean
argument to enable/disable the checking. This function in turn returns
a the tstrict interface:

2. Then strict checking is explicitly applied to the '_G' global table.

3. From there on global variables must be defined with 'VAR.',
'TYPED.', 'CONST.' or 'CONSTRAIN.' prefixes. After definition they can
be used like any other member as long the constraints are not
violated.

4. Redefining a variable without erasing it first yields an error
unless it is redefined with exactly the same value (to make the
+x.VAR = x or init+ idiom work)

5. 'tstrict' only applies to tables, due to Lua limitations it can not
check single local assignment. To facilitate strict checking on local
variables these need to be table members as shown with the 'local my =
strict {}' idiom.

6. Finally the example shows how to use undefine a variable and then
define it anew with 'CONSTRAIN' function. Such an definition takes a
{value, func(value, key, table)} pair as parameter and must return 'true'
when a values is accepted..


Notes
~~~~~

Tstrict is under development, features and API are still in flux but
will eventually stabilize for a 1.0 version.
