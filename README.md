
This is a `.ini` file parser and writer, with some (optional) additional machinery to automatically convert Jai `struct`s to and from `.ini` files.

Because `.ini` is a simple format with no formal specification which many people extend in unpredictable ways, we limit ourselves to what we consider common, 'modern' (mostly talking about not supporting utf-16 here), and useful features. We are not suitable to be used as a `.ini` format validator. More details are in the [Caveats and Implementation Notes section](#caveats-and-implementation-notes).

# Quick Start

Clone this repository:

```
git clone git@github.com:churchianity/jaini.git
```

And copy the entire resulting `jaini/` folder into your modules directory.

Usage Examples (mostly valid pseudocode):

```jai
#import "jaini";

//------------------------------------------------------------------------------
// 1. manual mode - reading:
contents := ... // load your .ini file contents into memory.
                // we mutate the string, so this variable must be writable.
pair: Ini_Pair;
while read_ini_pair(*contents, *pair) {
    // do something with the successfully parsed key-value .ini pair
}
if pair.error {
    // we encountered an issue!
}

//------------------------------------------------------------------------------
// 2. writing .ini data from struct directly
my_struct: ... // some struct value you have sitting around.
str := write_ini(my_struct);
// 'str' will contain .ini data that encodes the struct, that 'read_ini' 
// will be able to re-populate into a struct of the same (or just similar) type

//------------------------------------------------------------------------------
// 3. reading .ini data directly into struct
contents := ... // load your .ini file contents into memory
                // we mutate the string, so this variable must be writable.
my_struct: My_Struct;
success, error_msg := read_ini(*contents, *my_struct);
assert(success, error_msg);
// 'my_struct' will be populated recursively by the parsed .ini pairs
// we'll print warnings about pairs that have no corresponding struct member

//------------------------------------------------------------------------------
// 4. manual mode - writing:
// these trivial utilities are here for convienence and completeness.
builder: String_Builder; // from "jai/modules/Basic"

// will be written as: '; This is my configuration file!'
write_ini_comment(*builder, "This is my configuration file!");

// will be written as: '[My Section Name]'
write_ini_section(*builder, "My Section Name");

// will be written as: 'key = value'
write_ini_pair(*builder, "key", "value");

```

## Tests
We have a modest test-suite in `test.jai`. Instructions for running it are at the top of that file.

# Caveats and Implementation Notes
- utf-8 or ascii only (sorry, no utf-16)
- empty sections will be ignored by the parser
- keys within a section are not checked for uniqueness. `read_ini_pair` will pass you them all, and `read_ini` will use the last-most one
- string values parsed preserve the backslashes within them exactly
- values parsed can be quoted in single or double quotes, or not quoted at all
- multiline strings must be quoted
- comments are discarded by the parser.
- comments can be in the '#' or ';' variant, full single-line or after a key-value pair
- depends on `Basic`. If `INCLUDE_SERIALIZATION_PROCS` is set to true, also depends on `String` and `Reflection`
- parsing using the manual mode of `read_ini_pair` does not perform allocations
- `read_ini` performs temporary allocations when looking up struct members
- writing .ini file data will perform `context.alloc` allocations via `String_Builder`

## `read_ini`/`write_ini` Caveats
These are things we may support *in the automatic serialization codepaths* in the future, but currently do not:
- multiline strings don't support escaping quotes, so their delimiting quotemarks must not occur in the content of the string right now
- arrays of strings are not supported
- unions, tagged unions
- array views (though we do support fixed and resizable arrays)
- fixed/resizable arrays of dimension >= 2 (like `[2][2]int`, etc.)

