
This is a `.ini` file parser and writer, with some (optional) additional machinery to automatically convert Jai `struct`s to and from `.ini` files.

Because `.ini` is a simple format with no formal specification which many people extend in unpredictable ways, we limit ourselves to what we consider common, modern, and useful features. We are not suitable to be used as a `.ini` format validator. More details are in the [Caveats and Implementation Notes section](caveats-and-implementation-notes).

# Quick Start

Add `module.jai` to your modules folder (you may want to put it inside of a folder called 'jaini')

Examples (mostly valid pseudocode):

```jai

    #import "jaini";

    //--------------------------------------------------------------------------------
    // 1. manual mode - reading:
    contents := ... // load your .ini file contents into memory somehow.
                    // we mutate the string, so if it's constant, or you want to keep the original, do:
                    // contents := MY_CONSTANT_STRING;
                    // first.
    pair: Ini_Pair;
    while read_ini_pair(*contents, *pair) {
        // do something with the successfully parsed key-value .ini pair
    }
    if pair.error {
        // we encountered an issue, information is on line, column, and 'error'
    }

    //--------------------------------------------------------------------------------
    // 2. writing .ini data from struct directly
    my_struct: ... // some struct value you have sitting around.
    str := write_ini(my_struct);
    // 'str' will contain a .ini file that encodes the struct, that 'read_ini' will be able to
    // re-populate into a struct of the same (or just similar) type.

    //--------------------------------------------------------------------------------
    // 3. reading .ini data directly into struct
    contents := ... // load your .ini file contents into memory somehow
                    // we mutate the string, so if it's constant, or you want to keep the original, do:
                    // contents := MY_CONSTANT_STRING;
                    // first.
    my_struct: My_Struct;
    read_ini(*contents, *my_struct);
    // 'my_struct' will be populated recursively by the parsed .ini pairs
    // we'll print warnings about pairs that have no corresponding entry in the struct

    //--------------------------------------------------------------------------------
    // 4. manual mode - writing:
    // these trivial utilities are here for convienence and completeness.
    builder: String_Builder; // from "jai/modules/Basic"

    // will be written as: '; This is my configuration file!'
    write_ini_comment(*builder, "This is my configuration file!");

    // will be written as: '[My Section Name]'
    write_ini_section(*builder, "My Section Name");

    // will be written as: 'key = value' (convert your values to strings yourself first)
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
- comments are discarded by the parser. support reading comments in the '#' or ';' variant, full single-line or after a key-value pair
- depends on `Basic`, `String`, `Reflection` from `jai/modules/`
- allocations during runtime are either temporary allocations, or `context.alloc` for `String_Builder`

Because `.ini` is such a simple format with no formal specification, many people use it in unusual ways and implement the additional necessary machinery in their parser as needed.

## `read/write_ini` Caveats
These are things we *could* support in the automatic serialization codepaths, but currently do not:
- arrays of strings are not supported because of a corner case with multiline strings
- unions, tagged unions
- array views (though we do support fixed and resizable arrays. this one we may or may not choose to not support long term)
- arrays of dimension >= 2

