

# Quick Start

Add `module.jai` to your modules folder (you may want to put it inside of a folder called 'jaini')

Examples (mostly valid pseudocode):

```jai

main :: () {

    //--------------------------------------------------------------------------------
    // 1. manual mode - reading:
    contents := ... // load your ini file contents into memory somehow.
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
    // 2. manual mode - writing:
    // these trivial utilities are here for convienence and completeness.
    builder: String_Builder; // from "jai/modules/Basic"
    write_ini_comment(*builder, "This is my configuration file!"); // will be written as: '; This is my configuration file!'
    write_ini_section(*builder, "My Section Name");                // will be written as: '[My Section Name]'
    write_ini_pair(*builder, "key", "value");                      // will be written as: 'key = value' (convert your values to strings yourself first)

    //--------------------------------------------------------------------------------
    // 3. reading .ini data directly into struct
    contents := ... // load your ini file contents into memory somehow
                    // we mutate the string, so if it's constant, or you want to keep the original, do:
                    // contents := MY_CONSTANT_STRING;
                    // first.
    my_struct: My_Struct;
    read_ini(*contents, *my_struct);
    // 'my_struct' will have the fields in the ini written into it, recursively for nested structs and arrays

    //--------------------------------------------------------------------------------
    // 4. writing .ini data from struct directly
    my_struct: ... // some struct value you have sitting around.
    str := write_ini(my_struct);
    // 'str' will contain a .ini file that encodes the struct, that 'read_ini' will be able to
    // re-populate into a struct of the same (or just similar) type.
}

#import "jaini";

```

# Caveats/Implementation Notes

These are things we *could* support in the automatic serialization codepaths, but currently do not:
- @TODO multi-line strings
- @TODO unions
- @TODO tagged unions
- @TODO array views (this one we may or may not choose to not support long term)
- @TODO arrays of dimension >= 2

- we can read comments starting with '#' or ';'. comments can be full-line or started after a key-value pair.
  comments are discarded by the parser.

  we only *write* comments in the full-single-line, ';' variant.

- values parsed can be quoted in single or double quotes, or not quoted at all.
  we always write strings as delimited with double quotes

- string values parsed preserve the backslashes within them exactly

- empty sections will be ignored by the parser when reading

- allocations during runtime are either temporary allocations, or `context.alloc` for `String_Builder`

- depends on `Basic, `String`, `Reflection` from `jai/modules/`

- `write_ini` and `read_ini` do not write or read array views (though they do read/write fixed and resizable arrays)

- we don't validate that keys within a section are unique. if multiple exist, you will get passed all of them by `read_ini_pair`. `read_ini` will just use the last-most one in the file.

- utf-8/ascii only. There are a lot of utf-16 encoded .ini files on windows - we won't read these correctly.
  we thought about supporting this, but as most of the world has decided (correctly, we think) that utf-16
  is not a good idea, we will deliberately discourage its use. If you wanted to read windows .ini file data,
  winbase.h does have [some tools for this](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getprivateprofilestring)

  though, I cannot vouch for their efficacy.

