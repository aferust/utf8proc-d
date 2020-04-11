# A D port of utf8proc

- Ported from [utf8proc](https://github.com/JuliaStrings/utf8proc) version 2.5.0
- Ported with some help of [dstep](https://github.com/jacob-carlborg/dstep)
- Works with -betterC

## An example

```d
import core.stdc.string;
import core.stdc.stdlib;
import core.stdc.stdio;

import utf8proc;

@nogc nothrow:

extern (C) int main()
{
    string mstring = "ğüşöç ııİıııŞıÜııÇıı"; // 20 entries
    
    // duplicate mstring and cast it to ubyte*
    ubyte* mstr = cast(ubyte*)malloc((mstring.sizeof / ubyte.sizeof) * mstring.length);
    memcpy(mstr, mstring.ptr, (mstring.sizeof / ubyte.sizeof) * mstring.length);

    // some buffer for output. 
    ubyte** dst = cast(ubyte**)malloc((ubyte*).sizeof * mstring.sizeof);

    auto sz = utf8proc_map(mstr, mstring.sizeof, dst, UTF8PROC_NULLTERM);

    printf("your string: %s \n", cast(char*)*dst);
    
    utf8proc_ssize_t size = sz;
    utf8proc_int32_t data;
    utf8proc_ssize_t n;

    utf8proc_uint8_t* char_ptr = mstr;

    printf("Those are your utf8 characters one by one: \n".ptr);

    size_t nchar;

    while ((n = utf8proc_iterate(char_ptr, size, &data)) > 0) {
        printf("%.*s \n", cast(int)n, char_ptr);
        char_ptr += n;
        size -= n;
        nchar++;
    }

    // assert(nchar == 20);
    printf("You have %d entries in your string!", nchar);

    free(mstr);
    free(dst);
    
    return 0;
}
```