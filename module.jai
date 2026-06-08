#module_parameters(
    // include procs for automatically reading/writing ini file data directly from/to Jai structs
    // all other module parameters do nothing if this is false.
    INCLUDE_SERIALIZATION_PROCS                 := true,

    // if true we'll write a comment for struct members like .PROCEDURE, .OVERLOAD_SET, etc.
    WRITE_UNSUPPORTED_STRUCT_FIELDS_AS_COMMENTS := true,

    // if true, VectorX's will be written out as arrays of floats on one line, instead of as a struct
    TREAT_MATH_MODULE_VECTORS_AS_PRIMITIVES     := true,

    // when using 'write_ini' to write structs directly, skip members with this note on them
    NO_SERIALIZE_NOTE                           := "NO_SERIALIZE"
);

Ini_Pair :: struct {
    section, key, value: string; // section and value may be empty, key cannot be. views into the source .ini data

    error: string; // if set and we return false from 'read_ini_pair/read_ini', we encountered an error during parsing. Temporary or constant memory
                   // you can get the location in the source data where we encountered an issue by taking the current address of 'file_contents'
                   // and subtracting it from the original base address to get the byte offset (though this may be inexact).
}

// 'file_contents' must be writable, as we advance through the string as we parse.
read_ini_pair :: (file_contents: *string, p: *Ini_Pair) -> there_is_still_more_to_read: bool {
    assert(file_contents != null);
    assert(p             != null);

    skip :: (str: string, error_message_if_we_hit_the_end: string = "") -> string #expand {
        s := str;
        while s.count > 0 && is_space(s[0]) s = advance(s);
        if s.count == 0 { p.error = error_message_if_we_hit_the_end; `return false; }
        return s;
    }

    advance :: (str: string, error_message_if_we_hit_the_end: string = "") -> string #expand {
        s := advance(str, 1);
        if s.count == 0 { p.error = error_message_if_we_hit_the_end; `return false; }
        return s;
    }

    p.key   = "";
    p.value = "";

    str := file_contents.*;

    while str.count > 0 {
        str = skip(str);
        if str[0] == #char ";" || str[0] == #char "#" {
            while str.count > 0 && str[0] != #char "\n" str = advance(str);

        } else if str[0] == #char "[" { // parse a section
            str = advance(str);
            start := str.data;
            while str.count > 0 {
                if str[0] == #char "]" {
                    p.section = to_string(start, str.data-start);
                    str = advance(str);
                    break;
                }
                str = advance(str, "Unexpected end when looking for closing brace!");
            }
            if p.section == "" then log("Warning: found empty section!");
        } else { // parse a key-value pair. must be there, because getting here means it's not a comment, whitespace, or section '['
            // parse the key
            key_start := str.data;
            trailing_whitespace := 0;
            while str.count > 0 && str[0] != ":" && str[0] != "=" {
                if is_space(str[0]) trailing_whitespace += 1; else trailing_whitespace = 0;
                str = advance(str, tprint("Unexpected end looking for key! count %, str: |%|", str.count, str));
            }
            p.key = to_string(key_start, str.data-key_start-trailing_whitespace);

            // equal sign (or colon), with optional whitespace around it
            str = skip(str, "Unexpected end looking for equal sign or colon in key-value pair!");
            if str[0] != #char "=" && str[0] != #char ":" { p.error = tprint("Parsed a key '%', but didn't find a equal sign or colon after it...", p.key); return false; }
            str = advance(str, "Unexpected end looking for value in key-value pair!");
            str = skip(str, "Unexpected end looking for value in key-value pair!");

            // the value. delimited by a non-escaped newline. strings may also be inside single or double quotes
            success, value := read_ini_string(*str);
            if !success { p.error = value; return false; }
            p.value = value;

            file_contents.*=str;
            return true;
        }
    }

    return false;
}

// @TODO add support for escaped quotes
read_ini_string :: (_str: *string) -> (success: bool, value_or_error_string: string) {
    quotemark, carriage_return: u8;
    str := _str.*;
    value_start := str.data;
    if str[0] == #char "\"" || str[0] == #char "'" { quotemark = str[0]; str = advance(str, 1); }
    if str.count == 0 return false, "Unexpected end of stream!";
    backslash_count := 0;
    while str.count > 0 {
        if str[0] == #char "\\" {
            backslash_count += 1;
        } else if str[0] == #char "\n" && backslash_count & 1 == 0 #no_abc { // non-escaped newline.
            previous := str[-1];
            if previous == #char "\r" {
                previous = str[-2];
                carriage_return += 1;
            }
            if !quotemark || previous == quotemark { // either there's no beginning quotemark at all, or the character before the newline is the quotemark, so we should end the string.
                break;
            }
        } else {
            backslash_count = 0;
        }
        str = advance(str, 1);
    }
    _str.*=str;
    s := to_string(value_start, str.data-value_start-carriage_return);
    return true, s;
}

write_ini_section :: inline (builder: *String_Builder, section_name: string) {
    assert(section_name != "");
    assert(builder != null);
    print(builder, "\n[%]\n", section_name);
}

write_ini_comment :: inline (builder: *String_Builder, comment: string) {
    assert(builder != null);
    print(builder, "; %\n", comment);
}

// writes 'value' literally as-is, so convert your values to strings first as you see fit (tprint may suffice)
write_ini_pair :: inline (builder: *String_Builder, key: string, value: string, trailing_comment := "") {
    assert(builder != null);
    assert(key     != "");
    print(builder, "% = %", key, value);
    if trailing_comment print(builder, " ; %", trailing_comment);
    print(builder, "\n");
}

#if INCLUDE_SERIALIZATION_PROCS {
// writes a struct value into a .ini string. returned string is allocated with context.alloc (uses String_Builder)
write_ini :: (value: $T) -> string
#modify {
    return (cast(*Type_Info)T).type == .STRUCT;
} {
    #insert #run,stallable generate_ini_serialization_code(cast(*Type_Info_Struct)T);
}

// reads a .ini string and populates the struct value pointed to by 'v' with its contents.
//
// if 'strip_quotes' is true, we will remove quotes from the beginning and end of strings
// we parse before storing it into the struct.
//
// if 'copy_strings' is true, we'll call 'copy_string' on all string values we encounter as
// we assign to 'v', otherwise the strings will be string views into the source string 'ini'.
//
read_ini :: (ini: *string, v: *$T, strip_quotes := true, copy_strings := true) -> success: bool, error: string
#modify {
    return (cast(*Type_Info)T).type == .STRUCT;
} {
    assert(ini != null);
    assert(v   != null);
    base := ini.*;
    pair: Ini_Pair;
    while read_ini_pair(ini, *pair) {
        a: Any;
        lookup_writable_struct_member(*a, cast(*Type_Info_Struct)type_info(T), v, pair.section, pair.key);
        if a.value_pointer == null {
            log("Warning: Didn't find an entry in the struct for pair: %", pair);
            continue; // value in .ini stream but not in struct.
        }
        success := set_ini_value_from_string(a, pair.value, strip_quotes, copy_strings);
        assert(success, "Failed to set value from string (pair %)", pair);
    }
    if pair.error {
        log_error("error (byte offset: %): %", ini.data - base.data, pair.error);
        return false, pair.error;
    }
    return true, "";
}

#scope_file

lookup_writable_struct_member :: (a: *Any, tis: *Type_Info_Struct, p: *void, section: string, key: string, offset := 0, prefix: string = "") {
    assert(a   != null);
    assert(tis != null);
    assert(p   != null);

    auto_release_temp();
    lookup_key := tprint("%.%", section, key);

    for * member : tis.members {
        member_key_with_trailing_dot := tprint("%.%.", prefix, member.name);
        member_key := slice(member_key_with_trailing_dot, 0, member_key_with_trailing_dot.count-1);
        if member_key == lookup_key {
            a.type = member.type;
            a.value_pointer = p + member.offset_in_bytes + offset;
            return;

        } else if member.type.type == .ARRAY {
            tia := member.type.(*Type_Info_Array);
            if tia.array_type == .VIEW continue;
            if starts_with(lookup_key, member_key_with_trailing_dot) {
                assert(tia.element_type.type == .STRUCT); // arrays of primitives will have exact matches on the member key and be caught in the first if-statement.
                // the key might contain array index(es). we need to ensure the array on the struct, if it exists, has room for the index.
                data_pointer: *void;
                i := prefix.count;
                while i < lookup_key.count {
                    c := lookup_key[i];
                    if c == #char "." {
                        array_index, ok, remainder := string_to_int(slice(lookup_key, i+1, lookup_key.count-i));
                        if !ok { i += 1; continue; } // this will never be a false positive because Jai currently does not allow identifiers to be entirely digits.
                        if tia.array_type == .RESIZABLE #no_abc {
                            resizable_array := (p + member.offset_in_bytes + offset).(*Resizable_Array);
                            array_reserve(resizable_array, array_index+1, tia.element_type.runtime_size); // ensure we have enough space for the parsed array index
                            old_count := resizable_array.count;
                            resizable_array.count = max(array_index+1, resizable_array.count);
                            data_pointer = resizable_array.data + array_index*tia.element_type.runtime_size;
                            tis := tia.element_type.(*Type_Info_Struct);
                            if tis.initializer && old_count < resizable_array.count { // since we're bypassing the array's initialization code otherwise. @NOTE only works if array elements are monotonically increasing
                                tis.initializer(data_pointer);
                            }
                        } else if tia.array_type == .FIXED {
                            if array_index < tia.array_count {
                                data_pointer = p + member.offset_in_bytes + offset + array_index * tia.element_type.runtime_size;
                            } else {
                                log("Warning: key: '%' refers to an array index that is out-of-bounds of the fixed-size array to which it refers (array member name is: '%', and has size: %)", lookup_key, member.name, tia.array_count);
                                continue member;
                            }
                        }
                        assert(data_pointer != null);
                        i += lookup_key.count - i - remainder.count;
                        lookup_writable_struct_member(a, tia.element_type.(*Type_Info_Struct), data_pointer, section, key, 0, tprint("%0%0", member_key_with_trailing_dot, array_index));
                        return;
                    }
                    i += 1;
                }
            }
        } else if member.type.type == .STRUCT {
            if starts_with(lookup_key, member_key_with_trailing_dot) {
                lookup_writable_struct_member(a, member.type.(*Type_Info_Struct), p, section, key, offset + member.offset_in_bytes, member_key);
                return;
            }
        }
    }
}
}

// @NOTE this started as the proc from the Reflection module 'set_value_from_string'
set_ini_value_from_string :: (_any: Any, text: string, strip_quotes := true, copy_strings := true) -> bool, remainder: string {
    assert(_any.value_pointer != null);
    assert(_any.type          != null);

    any := _any;
    any.type = reduce_type(any.type);

    if any.type.type == {
        case .ARRAY;
            tia := any.type.(*Type_Info_Array);
            if tia.array_type == .VIEW return false, ""; // we don't currently support array views.
            array_base := any.value_pointer;
            ra: *Resizable_Array;
            if tia.array_type == .RESIZABLE then ra = array_base.(*Resizable_Array);
            element_any: Any = Any.{ tia.element_type, null };
            t := text;
            i := 0;
            while true {
                defer i += 1;

                if tia.array_type == .RESIZABLE {
                    array_reserve(ra, i+1, tia.element_type.runtime_size);
                    array_base = ra.data;
                }

                element_any.value_pointer = array_base + i * tia.element_type.runtime_size;
                success:, t = set_ini_value_from_string(element_any, t, strip_quotes, copy_strings);
                // if it's a resizable array, we stop when we fail to parse (because this is for primitives,
                // so we don't parse anything telling us how many things there are). If it's fixed, we stop
                // once we reach the array count and parsing should never fail.
                if (tia.array_count == -1 && !success) || (i == tia.array_count-1) {
                    return true, t;
                }
                assert(success);
                if !success return false, "";
                if tia.array_type == .RESIZABLE then ra.count = max(i+1, ra.count);
            }
            return true, t;

        case .INTEGER;
            i, success, remainder := string_to_int(text);
            if !success return false, "";

            ti_integer := cast(*Type_Info_Integer)any.type;
            valid: bool;
            if ti_integer.signed {
                valid = range_check_and_store(i      , ti_integer, any.value_pointer);
            } else {
                valid = range_check_and_store(i.(u64), ti_integer, any.value_pointer);
            }
            if !valid {
                log("Warning: integer value it out of bounds of the integer type in the corresponding struct. Int is: %, and the type is size: %, signed: %", i, ti_integer.runtime_size, ti_integer.signed);
                return false, "";
            }
            return true, remainder;

        case .FLOAT;
            success: bool;
            remainder: string;
            if any.type.runtime_size == 4 {
                f:, success, remainder = string_to_float(text);
                if !success return false, remainder;
                (.*)cast(*float)any.value_pointer = f;
            } else if any.type.runtime_size == 8 {
                f:, success, remainder = string_to_float64(text);
                if !success return false, remainder;
                (.*) cast(*float64)any.value_pointer = f;
            } else {
                return false, "";
            }
            return true, remainder;

        case .BOOL;
            b: bool;
            length: s64 = 5;
            if starts_with(text, "true") {
                b = true;
                length = 4;
            } else if !starts_with(text, "false") {
                return false, "";
            }
            any.value_pointer.(*bool).* = b;
            return true, advance(text, length);

        case .STRING;
            t := text;
            success, s := read_ini_string(*t);
            assert(success);
            //if !success return false, "";
            if strip_quotes && s.count >= 2 && (s[0] == #char "\"" && s[s.count-1] == #char "\"") || (s[0] == #char "'" && s[s.count-1] == #char "'") {
                s = slice(s, 1, s.count-2);
            }
            any.value_pointer.(*string).* = ifx copy_strings then copy_string(s) else s;
            return true, t;

        case .ENUM;
            enum_type := cast(*Type_Info_Enum)any.type;
            // First, try to parse it as an integer.
            _any := any;
            _any.type = enum_type.internal_type;
            t := text;

            success:, t = set_ini_value_from_string(_any, t);

            // If that doesn't work, try to parse the enum names.
            if !success {
                value: int;
                t = text;
                found: bool;
                while true {
                    token, success := parse_token(*t);
                    if !success break;
                    for enum_type.names {
                        if it == token {
                            value |= enum_type.values[it_index];
                            found = true;
                            break;
                        }
                    }
                    if token != "|" && !found break;
                }

                if found {
                    success = true;
                    if      enum_type.runtime_size == 1 { any.value_pointer.(* s8).* = xx value; }
                    else if enum_type.runtime_size == 2 { any.value_pointer.(*s16).* = xx value; }
                    else if enum_type.runtime_size == 4 { any.value_pointer.(*s32).* = xx value; }
                    else if enum_type.runtime_size == 8 { any.value_pointer.(*s64).* =    value; }
                    return true, t;
                }
            }
            if !success return false, "";
            return true, t;
    }
    return false, "";
}

#if INCLUDE_SERIALIZATION_PROCS {
reduce_type :: (ti: *Type_Info) -> *Type_Info, string {
    property_suffix: string;
    while true {
        if ti.type == .VARIANT {
            ti = ti.(*Type_Info_Variant).variant_of;
        } else {
            #if TREAT_MATH_MODULE_VECTORS_AS_PRIMITIVES {
                if ti == Vector2_Type_Info || ti == Vector3_Type_Info || ti == Vector4_Type_Info {
                    ti = get_struct_field_info(ti.(*Type_Info_Struct), "component").type; // @FRAGILE tied to the name of the 'array' inside vectors in the math module.
                    assert(ti != null, "Looks like someone changed what the variable name of the 'components' inside Math module vectors was! We'll need to change the strings above and below this line.");
                    property_suffix = ".component";
                    continue;
                }
            }
            break;
        }
    }
    return ti, property_suffix;
}

generate_ini_serialization_code_for_struct :: (builder: *String_Builder, stack: *[..]Ini_Section_Descriptor, section: Ini_Section_Descriptor) #compile_time {
    assert(builder     != null);
    assert(stack       != null);
    assert(section.tis != null);

    indent := INDENTS[clamp(section.indent, 0, INDENTS.count-1)];

    for section.tis.members {
        if (it.flags & (.CONSTANT | .OVERLAY)) != 0 || array_find(it.notes, NO_SERIALIZE_NOTE) continue;

        ti, array_suffix := reduce_type(it.type);

        // Example 'path':
        // "value.intermediate_member_names.member_name.0"
        //
        //                                     dot
        //                                      |
        //                                      v
        // "value" ".intermediate_member_names" . "member_name" ".component"
        //
        //
        // name_prefix = "value" or "it"
        // name_infix  = ".intermediate_member_names"
        // it.name     = "member_name"
        // array_suffx = ".component" or "" (only used in the case of Math module vectors)
        //
        path := tprint("%0%0.%0%0", section.name_prefix, section.name_infix, it.name, array_suffix);

        if ti.type == .ARRAY && ti.(*Type_Info_Array).array_type != .VIEW {
            tia := cast(*Type_Info_Array)ti;
            // arrays of primitives are treated as primitives (not getting their own section)
            if tia.element_type.type == .INTEGER || tia.element_type.type == .FLOAT || tia.element_type.type == .ENUM || tia.element_type.type == .BOOL {
                print(builder, "%print(*builder, \"% = \");\n", indent, it.name);
                print(builder, "%for % print(*builder, \"\% \", it);\n", indent, path);
                print(builder, "%print(*builder, \"\\n\");\n", indent);
                continue;
            } else if tia.element_type.type == .STRUCT {
                grown_infix       := ifx it.name == "" then section.name_infix else tprint("%.%", section.name_infix, it.name); // handle anonymous structs
                next_section_name := tprint("%.\%", grown_infix);
                array_add(stack, .{ next_section_name, "it", "", tia.element_type.(*Type_Info_Struct), section.indent+1, path });
                continue;
            }
        }

        if ti.type == .STRUCT {
            grown_infix       := ifx it.name == "" then section.name_infix else tprint("%.%", section.name_infix, it.name); // handle anonymous structs
            next_section_name := tprint("%.%", section.section_name, it.name);
            array_add(stack, { next_section_name, section.name_prefix, grown_infix, ti.(*Type_Info_Struct), section.indent, "" });
        } else if ti.type == .INTEGER || ti.type == .FLOAT || ti.type == .ENUM || ti.type == .BOOL {
            print(builder, "%print(*builder, \"% = \%\\n\", %);\n", indent, it.name, path);
        } else if ti.type == .STRING { // same as primitives but wrapped in double-quotes.
            print(builder, "%print(*builder, \"% = \\\"\%\\\"\\n\", %);\n", indent, it.name, path);
        } else {
            #if WRITE_UNSUPPORTED_STRUCT_FIELDS_AS_COMMENTS print(builder, "%print(*builder, \"; % (skipped, type is %)\\n\");\n", indent, it.name, it.type.type);
        }
    }
}

Ini_Section_Descriptor :: struct {
    section_name: string; // similar to name prefix/infix but may contain array indices like "array.1.foo" etc.

    name_prefix: string; // "value" or "it" (when inside an array)
    name_infix: string;  // ex: ".intermediate.member.names"

    tis: *Type_Info_Struct;
    indent: s64;
    path_to_array: string;
}

generate_ini_serialization_code :: (tis: *Type_Info_Struct) -> string #compile_time {
    assert(tis != null);

    stack: [..]Ini_Section_Descriptor;
    array_add(*stack, .{ "", "value", "", tis, 0, "" });

    builder: String_Builder;
    print(*builder, "    builder: String_Builder;\n");

    prev_indent     := 0;
    is_inside_array := false;
    while stack.count > 0 {
        s := pop(*stack);
        assert(ends_with(s.section_name, s.name_infix), "%", s);
        indent := INDENTS[clamp(s.indent, 0, INDENTS.count-1)];
        if s.indent > prev_indent {
            is_inside_array = true;
            iterator := to_string(*ITERATORS[s.indent], 1);
            print(*builder, "%for it, % : % {\n", INDENTS[prev_indent], iterator, s.path_to_array);
            print(*builder, "%print(*builder, \"\\n[%]\\n\", %);\n", indent, s.section_name, iterator);
        } else if s.section_name {
            if is_inside_array {
                iterator := to_string(*ITERATORS[s.indent], 1);
                print(*builder, "%print(*builder, \"\\n[%]\\n\", %);\n", indent, s.section_name, iterator);
            } else {
                print(*builder, "%print(*builder, \"\\n[%]\\n\");\n", indent, s.section_name);
            }
        }
        generate_ini_serialization_code_for_struct(*builder, *stack, s);
        if s.indent < prev_indent {
            is_inside_array = false;
            print(*builder, "%}\n", indent);
        }
        prev_indent = s.indent;
    }
    if is_inside_array then print(*builder, "    }\n");
    print(*builder, "    return builder_to_string(*builder);\n");
    return builder_to_string(*builder);
}

INDENTS :: string.[
    "    ",
    "        ",
    "            ",
    "                ",
    "                    ",
    "                        ",
    "                            ",
    "                                ", // we clamp to these, so you won't be more than 7 indentation levels ever. doesn't really matter since this is for generated code. whateva!
];

ITERATORS :: " ijklmnopqrstuvwxyzabcdefgh";

#import "String"; // starts_with, slice
#import "Reflection"; // range_check_and_store, get_struct_field_info

#if TREAT_MATH_MODULE_VECTORS_AS_PRIMITIVES {
    #import "Math"; // VectorX
    Vector2_Type_Info :: type_info(Vector2);
    Vector3_Type_Info :: type_info(Vector3);
    Vector4_Type_Info :: type_info(Vector4);
}
}

#import "Basic"; // String_Builder, print, advance, log, tprint, min, max, clamp

