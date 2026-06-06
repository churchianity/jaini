
// assuming this file is in a folder called 'jaini', you can compile this file standalone with: `jai test.jai`, and run it to run tests if you like.

#import "../../jaini"(INCLUDE_SERIALIZATION_PROCS = true, TREAT_MATH_MODULE_VECTORS_AS_PRIMITIVES = true);

#import "File";
#import "Basic";
#import "Math";

// Support for (and tests should cover):
// - all integer types (S128 support as a struct, not an integer)
// - enums
// - enum flags
// - all floats
// - bools
// - single-line strings
// - fixed-size and resizable arrays of 'primitives':
// - fixed-size and resizable arrays of structs
//  - enums, enum flags, floats, ints, bools
//  - @TODO strings
//
// - structs
// - @TODO unions
//
// - variants of any of the above, compounded by recursion

// @TOOD arrays of strings
// @TODO array views
// @TODO unions

ID :: #type,distinct u32;
Color :: #type,isa Vector4;

Enum :: enum { FLOOEY; DOINK; FLORBIUS; }
Flags :: enum_flags { ON_FIRE; ALIVE; STINKY; F; }

Test_Struct_A :: struct {
    f: float   =  64;
    d: float64 = 128;
    a: [2]float = .[ 0.5, 0.6 ];
    i: int     =  69;
    b: Test_Struct_B;
    u: u32     = 420;
    single_item_array: [1]int = .[ 123 ];
    s: string  = "foo";
}

Test_Struct_B :: struct {
    b := true;                      // b.b
    v: Vector2 = .{ -1, 110 };      // b.v
    col: Color = .{ 1, 0, 0.2, 1 }; // b.col
    s: string = "string2";          // b.s
    id: ID = 321;                   // b.id
    e: Enum = .DOINK;               // b.e
    c: Test_Struct_C;
}

Test_Struct_C :: struct {
    f: Flags = .ON_FIRE | .ALIVE; // b.c.f
    b: bool = true;               // b.c.b
    s: string = "string3";        // b.c.s
    using nested_struct : struct {
        prev, next: u64;
        another_nested_struct: struct {
            str := "deeply nested string";
        }
    };
}

Test_Struct_D :: struct {
    file_path: string = "foobar.xz";
    resizable_array_of_structs: [..]Test_Struct_C;
}

Test_Struct_E :: struct {
    resizable_array_of_primitives: [..]u32;
    multiline_string: string;
}

TEST_BUFFER1 :: #string END
f = 65
d = 129
a = 0.6 0.7
i = 70
u = 421
single_item_array = 4 2
s = "foo2"

[.b]
b = false
v = -2 111
col = 0 1 1 0
s = "プログラムプロジェクターを開く"
id = 322
e = FLORBIUS

[.b.c]
f = ALIVE
b = true
s = "string4"
END

TEST_BUFFER2 :: #string END
[.resizable_array_of_structs.0]
f = 0
b = true
s = "663"

[.resizable_array_of_structs.0.nested_struct]
prev = 123
next = 321

[.resizable_array_of_structs.1]
f = ON_FIRE
b = false
s = "2"

[.resizable_array_of_structs.1.nested_struct]
prev = 456
next = 654
END

TEST_BUFFER3 :: #string END
resizable_array_of_primitives = 9 8 7 6 5 4 3 2 1 0
multiline_string = "first line
second line with escaped quote\"
third line but this one is a little different."
a = 5
END

TEST_MULTILINE_STRING :: #string END
first line
second line with escaped quote\"
third line but this one is a little different.
END

main :: () {
    {
        #if 0 { // all primitive types, variants, arrays of primitives, multiple layers of nested structs
            test: Test_Struct_A;
            str := write_ini(test);

            log("\nwritten (1):\n%\n", str);

            // read the test buffer into the test struct, overwriting default values:
            in := TEST_BUFFER1;
            success := read_ini(*in, *test);
            assert(success, "The test buffer failed to be parsed by the .ini reader - this is pretty bad!");

            // now check that we read what we expect:
            assert(65.       == test.f,       "Failed to correctly read variable 'f'! Got: %",       test.f);
            assert(129.      == test.d,       "Failed to correctly read variable 'd'! Got: %",       test.d);
            assert(0.6       == test.a[0],    "Failed to correctly read variable 'a[0]'! Got: %",    test.a[0]);
            assert(0.7       == test.a[1],    "Failed to correctly read variable 'a[1]'! Got: %",    test.a[1]);
            assert(70        == test.i,       "Failed to correctly read variable 'i'! Got: %",       test.i);
            assert(421       == test.u,       "Failed to correctly read variable 'u'! Got: %",       test.u);
            assert(4         == test.single_item_array[0], "Failed to correctly read variable 'single_item_array'! Got: %", test.single_item_array);
            assert("foo2"    == test.s,       "Failed to correctly read variable 's'! Got: %",       test.s);
            assert(false     == test.b.b,     "Failed to correctly read variable 'b.b'! Got: %",     test.b.b);
            assert(-2        == test.b.v.x,   "Failed to correctly read variable 'b.v.x'! Got: %",   test.b.v.x);
            assert(111       == test.b.v.y,   "Failed to correctly read variable 'b.v.y'! Got: %",   test.b.v.y);
            assert(0         == test.b.col.x, "Failed to correctly read variable 'b.col.x'! Got: %", test.b.col.x);
            assert(1         == test.b.col.y, "Failed to correctly read variable 'b.col.y'! Got: %", test.b.col.y);
            assert(1         == test.b.col.z, "Failed to correctly read variable 'b.col.z'! Got: %", test.b.col.z);
            assert(0         == test.b.col.w, "Failed to correctly read variable 'b.col.w'! Got: %", test.b.col.w);
            assert("プログラムプロジェクターを開く" == test.b.s,     "Failed to correctly read variable 'b.s'! Got: %",     test.b.s);
            assert(322       == test.b.id,    "Failed to correctly read variable 'b.id'! Got: %",    test.b.id);
            assert(.FLORBIUS == test.b.e,     "Failed to correctly read variable 'b.e'! Got: %",     test.b.e);
            assert(.ALIVE    == test.b.c.f,   "Failed to correctly read variable 'b.c.f'! Got: %",   test.b.c.f);
            assert(true      == test.b.c.b,   "Failed to correctly read variable 'b.c.b'! Got: %",   test.b.c.b);
            assert("string4" == test.b.c.s,   "Failed to correctly read variable 'b.c.s'! Got: %",   test.b.c.s);
        }
    }

    {
        #if 0 { // arrays of structs, nesting, "using"
            test: Test_Struct_D;
            for 0..1 array_add(*test.resizable_array_of_structs, .{});
            str := write_ini(test);

            log("\nwritten (2):\n%\n", str);

            in := TEST_BUFFER2;
            array_reset(*test.resizable_array_of_structs);
            success := read_ini(*in, *test);
            assert(success, "The test buffer failed to be parsed by the .ini reader - this is pretty bad!");

            assert(test.resizable_array_of_structs.count == 2); // 'read_ini' should set the count to 2.
            assert(0        == test.resizable_array_of_structs[0].f,    "Failed to correctly read variable 'resizable_array_of_structs[0].f'! Got: %",    test.resizable_array_of_structs[0].f);
            assert(true     == test.resizable_array_of_structs[0].b,    "Failed to correctly read variable 'resizable_array_of_structs[0].b'! Got: %",    test.resizable_array_of_structs[0].b);
            assert("663"    == test.resizable_array_of_structs[0].s,    "Failed to correctly read variable 'resizable_array_of_structs[0].s'! Got: %",    test.resizable_array_of_structs[0].s);
            assert(123      == test.resizable_array_of_structs[0].prev, "Failed to correctly read variable 'resizable_array_of_structs[0].prev'! Got: %", test.resizable_array_of_structs[0].prev);
            assert(321      == test.resizable_array_of_structs[0].next, "Failed to correctly read variable 'resizable_array_of_structs[0].next'! Got: %", test.resizable_array_of_structs[0].next);
            assert(.ON_FIRE == test.resizable_array_of_structs[1].f,    "Failed to correctly read variable 'resizable_array_of_structs[1].f'! Got: %",    test.resizable_array_of_structs[1].f);
            assert(false    == test.resizable_array_of_structs[1].b,    "Failed to correctly read variable 'resizable_array_of_structs[1].b'! Got: %",    test.resizable_array_of_structs[1].b);
            assert("2"      == test.resizable_array_of_structs[1].s,    "Failed to correctly read variable 'resizable_array_of_structs[1].s'! Got: %",    test.resizable_array_of_structs[1].s);
            assert(456      == test.resizable_array_of_structs[1].prev, "Failed to correctly read variable 'resizable_array_of_structs[1].prev'! Got: %", test.resizable_array_of_structs[1].prev);
            assert(654      == test.resizable_array_of_structs[1].next, "Failed to correctly read variable 'resizable_array_of_structs[1].next'! Got: %", test.resizable_array_of_structs[1].next);
        }
    }

    {
        #if 1 { // @TODO two-dimensional arrays, unions,
            test: Test_Struct_E;
            for 0..9 array_add(*test.resizable_array_of_primitives, xx it);
            str := write_ini(test);

            log("\nwritten (3):\n%\n", str);

            in := TEST_BUFFER3;
            array_reset(*test.resizable_array_of_primitives);
            success := read_ini(*in, *test);
            assert(success, "The test buffer failed to be parsed by the .ini reader - this is pretty bad!");

            assert(test.resizable_array_of_primitives.count == 10, "%", test.resizable_array_of_primitives.count); // 'read_ini' should set the count to 10.
            for 0..9 assert(it == test.resizable_array_of_primitives[9-it], "Failed to correctly read variable 'resizable_array_of_primitives[%]! Got: %", 9-it, test.resizable_array_of_primitives[9-it]);

            assert(test.multiline_string == TEST_MULTILINE_STRING, "Failed to correctly read variable 'multiline_string'! Got: %", test.multiline_string);
        }
    }

    log("% test passed!", #file);
}

