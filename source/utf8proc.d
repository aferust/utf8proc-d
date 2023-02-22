/*
 * Copyright (c) 2014-2019 Steven G. Johnson, Jiahao Chen, Peter Colberg, Tony Kelman, Scott P. Jones, and other contributors.
 * Copyright (c) 2009 Public Software Group e. V., Berlin, Germany
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

/**
 * @mainpage
 *
 * utf8proc is a free/open-source (MIT/expat licensed) C library
 * providing Unicode normalization, case-folding, and other operations
 * for strings in the UTF-8 encoding, supporting up-to-date Unicode versions.
 * See the utf8proc home page (http://julialang.org/utf8proc/)
 * for downloads and other information, or the source code on github
 * (https://github.com/JuliaLang/utf8proc).
 *
 * For the utf8proc API documentation, see: @ref utf8proc.h
 *
 * The features of utf8proc include:
 *
 * - Transformation of strings (@ref utf8proc_map) to:
 *    - decompose (@ref UTF8PROC_DECOMPOSE) or compose (@ref UTF8PROC_COMPOSE) Unicode combining characters (http://en.wikipedia.org/wiki/Combining_character)
 *    - canonicalize Unicode compatibility characters (@ref UTF8PROC_COMPAT)
 *    - strip "ignorable" (@ref UTF8PROC_IGNORE) characters, control characters (@ref UTF8PROC_STRIPCC), or combining characters such as accents (@ref UTF8PROC_STRIPMARK)
 *    - case-folding (@ref UTF8PROC_CASEFOLD)
 * - Unicode normalization: @ref utf8proc_NFD, @ref utf8proc_NFC, @ref utf8proc_NFKD, @ref utf8proc_NFKC
 * - Detecting grapheme boundaries (@ref utf8proc_grapheme_break and @ref UTF8PROC_CHARBOUND)
 * - Character-width computation: @ref utf8proc_charwidth
 * - Classification of characters by Unicode category: @ref utf8proc_category and @ref utf8proc_category_string
 * - Encode (@ref utf8proc_encode_char) and decode (@ref utf8proc_iterate) Unicode codepoints to/from UTF-8.
 */ 

module utf8proc;

version(LDC){
  version(D_BetterC){
    pragma(LDC_no_moduleinfo);
  }
}

import stringnogc;

import utf8procdata;

/** @file */

@nogc nothrow:

/** @name API version
 *
 * The utf8proc API version MAJOR.MINOR.PATCH, following
 * semantic-versioning rules (http://semver.org) based on API
 * compatibility.
 *
 * This is also returned at runtime by @ref utf8proc_version; however, the
 * runtime version may append a string like "-dev" to the version number
 * for prerelease versions.
 *
 * @note The shared-library version number in the Makefile
 *       (and CMakeLists.txt, and MANIFEST) may be different,
 *       being based on ABI compatibility rather than API compatibility.
 */
/** @{ */
/** The MAJOR version number (increased when backwards API compatibility is broken). */
enum UTF8PROC_VERSION_MAJOR = 2;
/** The MINOR version number (increased when new functionality is added in a backwards-compatible manner). */
enum UTF8PROC_VERSION_MINOR = 5;
/** The PATCH version (increased for fixes that do not change the API). */
enum UTF8PROC_VERSION_PATCH = 0;
/** @} */

// MSVC prior to 2013 lacked stdbool.h and inttypes.h

// emulate C99 bool

alias utf8proc_int8_t = byte;
alias utf8proc_uint8_t = ubyte;
alias utf8proc_int16_t = short;
alias utf8proc_uint16_t = ushort;
alias utf8proc_int32_t = int;
alias utf8proc_uint32_t = uint;
alias utf8proc_size_t = ulong;
alias utf8proc_ssize_t = long;
alias utf8proc_bool = bool;

/**
 * Option flags used by several functions in the library.
 */

alias utf8proc_option_t = int;
enum : utf8proc_option_t
{
    /** The given UTF-8 input is NULL terminated. */
    UTF8PROC_NULLTERM = 1 << 0,
    /** Unicode Versioning Stability has to be respected. */
    UTF8PROC_STABLE = 1 << 1,
    /** Compatibility decomposition (i.e. formatting information is lost). */
    UTF8PROC_COMPAT = 1 << 2,
    /** Return a result with decomposed characters. */
    UTF8PROC_COMPOSE = 1 << 3,
    /** Return a result with decomposed characters. */
    UTF8PROC_DECOMPOSE = 1 << 4,
    /** Strip "default ignorable characters" such as SOFT-HYPHEN or ZERO-WIDTH-SPACE. */
    UTF8PROC_IGNORE = 1 << 5,
    /** Return an error, if the input contains unassigned codepoints. */
    UTF8PROC_REJECTNA = 1 << 6,
    /**
     * Indicating that NLF-sequences (LF, CRLF, CR, NEL) are representing a
     * line break, and should be converted to the codepoint for line
     * separation (LS).
     */
    UTF8PROC_NLF2LS = 1 << 7,
    /**
     * Indicating that NLF-sequences are representing a paragraph break, and
     * should be converted to the codepoint for paragraph separation
     * (PS).
     */
    UTF8PROC_NLF2PS = 1 << 8,
    /** Indicating that the meaning of NLF-sequences is unknown. */
    UTF8PROC_NLF2LF = UTF8PROC_NLF2LS | UTF8PROC_NLF2PS,
    /** Strips and/or convers control characters.
     *
     * NLF-sequences are transformed into space, except if one of the
     * NLF2LS/PS/LF options is given. HorizontalTab (HT) and FormFeed (FF)
     * are treated as a NLF-sequence in this case.  All other control
     * characters are simply removed.
     */
    UTF8PROC_STRIPCC = 1 << 9,
    /**
     * Performs unicode case folding, to be able to do a case-insensitive
     * string comparison.
     */
    UTF8PROC_CASEFOLD = 1 << 10,
    /**
     * Inserts 0xFF bytes at the beginning of each sequence which is
     * representing a single grapheme cluster (see UAX#29).
     */
    UTF8PROC_CHARBOUND = 1 << 11,
    /** Lumps certain characters together.
     *
     * E.g. HYPHEN U+2010 and MINUS U+2212 to ASCII "-". See lump.md for details.
     *
     * If NLF2LF is set, this includes a transformation of paragraph and
     * line separators to ASCII line-feed (LF).
     */
    UTF8PROC_LUMP = 1 << 12,
    /** Strips all character markings.
     *
     * This includes non-spacing, spacing and enclosing (i.e. accents).
     * @note This option works only with @ref UTF8PROC_COMPOSE or
     *       @ref UTF8PROC_DECOMPOSE
     */
    UTF8PROC_STRIPMARK = 1 << 13,
    /**
     * Strip unassigned codepoints.
     */
    UTF8PROC_STRIPNA = 1 << 14
}

/** @name Error codes
 * Error codes being returned by almost all functions.
 */
/** @{ */
/** Memory could not be allocated. */
enum UTF8PROC_ERROR_NOMEM = -1;
/** The given string is too long to be processed. */
enum UTF8PROC_ERROR_OVERFLOW = -2;
/** The given string is not a legal UTF-8 string. */
enum UTF8PROC_ERROR_INVALIDUTF8 = -3;
/** The @ref UTF8PROC_REJECTNA flag was set and an unassigned codepoint was found. */
enum UTF8PROC_ERROR_NOTASSIGNED = -4;
/** Invalid options have been used. */
enum UTF8PROC_ERROR_INVALIDOPTS = -5;
/** @} */

/* @name Types */

/** Holds the value of a property. */
alias utf8proc_propval_t = short;

/** Struct containing information about a codepoint. */
struct utf8proc_property_struct
{
    /**
     * Unicode category.
     * @see utf8proc_category_t.
     */
    utf8proc_propval_t category;
    utf8proc_propval_t combining_class;
    /**
     * Bidirectional class.
     * @see utf8proc_bidi_class_t.
     */
    utf8proc_propval_t bidi_class;
    /**
     * @anchor Decomposition type.
     * @see utf8proc_decomp_type_t.
     */
    utf8proc_propval_t decomp_type;
    utf8proc_uint16_t decomp_seqindex;
    utf8proc_uint16_t casefold_seqindex;
    utf8proc_uint16_t uppercase_seqindex;
    utf8proc_uint16_t lowercase_seqindex;
    utf8proc_uint16_t titlecase_seqindex;
    utf8proc_uint16_t comb_index;

    uint bidi_mirrored;
    uint comp_exclusion;
    uint ignorable;
    uint control_boundary;
    uint charwidth;
    uint pad;
    uint boundclass;

    // dstep suggested below code, but it does not work with betterC
    // Hope, this does not corrupt things. The example code works.
    /*
    import std.bitmanip : bitfields;
    mixin(bitfields!(
        uint, "bidi_mirrored", 1,
        uint, "comp_exclusion", 1,
        uint, "ignorable", 1,
        uint, "control_boundary", 1,
        uint, "charwidth", 2,
        uint, "pad", 2,
        uint, "boundclass", 8));
    */
    @nogc nothrow:
    this(
        utf8proc_propval_t category,
        utf8proc_propval_t combining_class,
        utf8proc_propval_t bidi_class,
        utf8proc_propval_t decomp_type,
        utf8proc_uint16_t decomp_seqindex,
        utf8proc_uint16_t casefold_seqindex,
        utf8proc_uint16_t uppercase_seqindex,
        utf8proc_uint16_t lowercase_seqindex,
        utf8proc_uint16_t titlecase_seqindex,
        utf8proc_uint16_t comb_index,
        uint bidi_mirrored,
        uint comp_exclusion,
        uint ignorable,
        uint control_boundary,
        uint charwidth,
        uint pad,
        uint boundclass
    ){
        this.category = category;
        this.combining_class = combining_class;
        this.bidi_class = bidi_class;
        this.decomp_type = decomp_type;
        this.decomp_seqindex = decomp_seqindex;
        this.casefold_seqindex = casefold_seqindex;
        this.uppercase_seqindex = uppercase_seqindex;
        this.lowercase_seqindex = lowercase_seqindex;
        this.titlecase_seqindex = titlecase_seqindex;
        this.comb_index = comb_index;
        this.bidi_mirrored = bidi_mirrored;
        this.comp_exclusion= comp_exclusion;
        this.ignorable = ignorable;
        this.control_boundary = control_boundary;
        this.charwidth = charwidth;
        this.pad = pad;
        this.boundclass = boundclass;
    }
    /**
     * Can this codepoint be ignored?
     *
     * Used by @ref utf8proc_decompose_char when @ref UTF8PROC_IGNORE is
     * passed as an option.
     */

    /** The width of the codepoint. */

    /**
     * Boundclass.
     * @see utf8proc_boundclass_t.
     */
}

alias utf8proc_property_t = utf8proc_property_struct;

/** Unicode categories. */
alias utf8proc_category_t = int;
enum : utf8proc_category_t
{
    UTF8PROC_CATEGORY_CN = 0, /**< Other, not assigned */
    UTF8PROC_CATEGORY_LU = 1, /**< Letter, uppercase */
    UTF8PROC_CATEGORY_LL = 2, /**< Letter, lowercase */
    UTF8PROC_CATEGORY_LT = 3, /**< Letter, titlecase */
    UTF8PROC_CATEGORY_LM = 4, /**< Letter, modifier */
    UTF8PROC_CATEGORY_LO = 5, /**< Letter, other */
    UTF8PROC_CATEGORY_MN = 6, /**< Mark, nonspacing */
    UTF8PROC_CATEGORY_MC = 7, /**< Mark, spacing combining */
    UTF8PROC_CATEGORY_ME = 8, /**< Mark, enclosing */
    UTF8PROC_CATEGORY_ND = 9, /**< Number, decimal digit */
    UTF8PROC_CATEGORY_NL = 10, /**< Number, letter */
    UTF8PROC_CATEGORY_NO = 11, /**< Number, other */
    UTF8PROC_CATEGORY_PC = 12, /**< Punctuation, connector */
    UTF8PROC_CATEGORY_PD = 13, /**< Punctuation, dash */
    UTF8PROC_CATEGORY_PS = 14, /**< Punctuation, open */
    UTF8PROC_CATEGORY_PE = 15, /**< Punctuation, close */
    UTF8PROC_CATEGORY_PI = 16, /**< Punctuation, initial quote */
    UTF8PROC_CATEGORY_PF = 17, /**< Punctuation, final quote */
    UTF8PROC_CATEGORY_PO = 18, /**< Punctuation, other */
    UTF8PROC_CATEGORY_SM = 19, /**< Symbol, math */
    UTF8PROC_CATEGORY_SC = 20, /**< Symbol, currency */
    UTF8PROC_CATEGORY_SK = 21, /**< Symbol, modifier */
    UTF8PROC_CATEGORY_SO = 22, /**< Symbol, other */
    UTF8PROC_CATEGORY_ZS = 23, /**< Separator, space */
    UTF8PROC_CATEGORY_ZL = 24, /**< Separator, line */
    UTF8PROC_CATEGORY_ZP = 25, /**< Separator, paragraph */
    UTF8PROC_CATEGORY_CC = 26, /**< Other, control */
    UTF8PROC_CATEGORY_CF = 27, /**< Other, format */
    UTF8PROC_CATEGORY_CS = 28, /**< Other, surrogate */
    UTF8PROC_CATEGORY_CO = 29 /**< Other, private use */
}

/** Bidirectional character classes. */
alias utf8proc_bidi_class_t = int;
enum : utf8proc_bidi_class_t
{
    UTF8PROC_BIDI_CLASS_L = 1, /**< Left-to-Right */
    UTF8PROC_BIDI_CLASS_LRE = 2, /**< Left-to-Right Embedding */
    UTF8PROC_BIDI_CLASS_LRO = 3, /**< Left-to-Right Override */
    UTF8PROC_BIDI_CLASS_R = 4, /**< Right-to-Left */
    UTF8PROC_BIDI_CLASS_AL = 5, /**< Right-to-Left Arabic */
    UTF8PROC_BIDI_CLASS_RLE = 6, /**< Right-to-Left Embedding */
    UTF8PROC_BIDI_CLASS_RLO = 7, /**< Right-to-Left Override */
    UTF8PROC_BIDI_CLASS_PDF = 8, /**< Pop Directional Format */
    UTF8PROC_BIDI_CLASS_EN = 9, /**< European Number */
    UTF8PROC_BIDI_CLASS_ES = 10, /**< European Separator */
    UTF8PROC_BIDI_CLASS_ET = 11, /**< European Number Terminator */
    UTF8PROC_BIDI_CLASS_AN = 12, /**< Arabic Number */
    UTF8PROC_BIDI_CLASS_CS = 13, /**< Common Number Separator */
    UTF8PROC_BIDI_CLASS_NSM = 14, /**< Nonspacing Mark */
    UTF8PROC_BIDI_CLASS_BN = 15, /**< Boundary Neutral */
    UTF8PROC_BIDI_CLASS_B = 16, /**< Paragraph Separator */
    UTF8PROC_BIDI_CLASS_S = 17, /**< Segment Separator */
    UTF8PROC_BIDI_CLASS_WS = 18, /**< Whitespace */
    UTF8PROC_BIDI_CLASS_ON = 19, /**< Other Neutrals */
    UTF8PROC_BIDI_CLASS_LRI = 20, /**< Left-to-Right Isolate */
    UTF8PROC_BIDI_CLASS_RLI = 21, /**< Right-to-Left Isolate */
    UTF8PROC_BIDI_CLASS_FSI = 22, /**< First Strong Isolate */
    UTF8PROC_BIDI_CLASS_PDI = 23 /**< Pop Directional Isolate */
}

/** Decomposition type. */
alias utf8proc_decomp_type_t = int;
enum : utf8proc_decomp_type_t
{
    UTF8PROC_DECOMP_TYPE_FONT = 1, /**< Font */
    UTF8PROC_DECOMP_TYPE_NOBREAK = 2, /**< Nobreak */
    UTF8PROC_DECOMP_TYPE_INITIAL = 3, /**< Initial */
    UTF8PROC_DECOMP_TYPE_MEDIAL = 4, /**< Medial */
    UTF8PROC_DECOMP_TYPE_FINAL = 5, /**< Final */
    UTF8PROC_DECOMP_TYPE_ISOLATED = 6, /**< Isolated */
    UTF8PROC_DECOMP_TYPE_CIRCLE = 7, /**< Circle */
    UTF8PROC_DECOMP_TYPE_SUPER = 8, /**< Super */
    UTF8PROC_DECOMP_TYPE_SUB = 9, /**< Sub */
    UTF8PROC_DECOMP_TYPE_VERTICAL = 10, /**< Vertical */
    UTF8PROC_DECOMP_TYPE_WIDE = 11, /**< Wide */
    UTF8PROC_DECOMP_TYPE_NARROW = 12, /**< Narrow */
    UTF8PROC_DECOMP_TYPE_SMALL = 13, /**< Small */
    UTF8PROC_DECOMP_TYPE_SQUARE = 14, /**< Square */
    UTF8PROC_DECOMP_TYPE_FRACTION = 15, /**< Fraction */
    UTF8PROC_DECOMP_TYPE_COMPAT = 16 /**< Compat */
}

/** Boundclass property. (TR29) */
alias utf8proc_boundclass_t = int;
enum : utf8proc_boundclass_t
{
    UTF8PROC_BOUNDCLASS_START = 0, /**< Start */
    UTF8PROC_BOUNDCLASS_OTHER = 1, /**< Other */
    UTF8PROC_BOUNDCLASS_CR = 2, /**< Cr */
    UTF8PROC_BOUNDCLASS_LF = 3, /**< Lf */
    UTF8PROC_BOUNDCLASS_CONTROL = 4, /**< Control */
    UTF8PROC_BOUNDCLASS_EXTEND = 5, /**< Extend */
    UTF8PROC_BOUNDCLASS_L = 6, /**< L */
    UTF8PROC_BOUNDCLASS_V = 7, /**< V */
    UTF8PROC_BOUNDCLASS_T = 8, /**< T */
    UTF8PROC_BOUNDCLASS_LV = 9, /**< Lv */
    UTF8PROC_BOUNDCLASS_LVT = 10, /**< Lvt */
    UTF8PROC_BOUNDCLASS_REGIONAL_INDICATOR = 11, /**< Regional indicator */
    UTF8PROC_BOUNDCLASS_SPACINGMARK = 12, /**< Spacingmark */
    UTF8PROC_BOUNDCLASS_PREPEND = 13, /**< Prepend */
    UTF8PROC_BOUNDCLASS_ZWJ = 14, /**< Zero Width Joiner */

    /* the following are no longer used in Unicode 11, but we keep
       the constants here for backward compatibility */
    UTF8PROC_BOUNDCLASS_E_BASE = 15, /**< Emoji Base */
    UTF8PROC_BOUNDCLASS_E_MODIFIER = 16, /**< Emoji Modifier */
    UTF8PROC_BOUNDCLASS_GLUE_AFTER_ZWJ = 17, /**< Glue_After_ZWJ */
    UTF8PROC_BOUNDCLASS_E_BASE_GAZ = 18, /**< E_BASE + GLUE_AFTER_ZJW */

    /* the Extended_Pictographic property is used in the Unicode 11
       grapheme-boundary rules, so we store it in the boundclass field */
    UTF8PROC_BOUNDCLASS_EXTENDED_PICTOGRAPHIC = 19,
    UTF8PROC_BOUNDCLASS_E_ZWG = 20 /* UTF8PROC_BOUNDCLASS_EXTENDED_PICTOGRAPHIC + ZWJ */
}

/**
 * Function pointer type passed to @ref utf8proc_map_custom and
 * @ref utf8proc_decompose_custom, which is used to specify a user-defined
 * mapping of codepoints to be applied in conjunction with other mappings.
 */
alias utf8proc_custom_func = int function (utf8proc_int32_t codepoint, void* data);

import core.stdc.stdlib;


enum _true = 1;
enum _false = 0;

enum SSIZE_MAX = size_t.max / 2;

enum UINT16_MAX = 65535U;

const utf8proc_int8_t[256] utf8proc_utf8class = [
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
  4, 4, 4, 4, 4, 4, 4, 4, 0, 0, 0, 0, 0, 0, 0, 0 ];

enum UTF8PROC_HANGUL_SBASE = 0xAC00;
enum UTF8PROC_HANGUL_LBASE = 0x1100;
enum UTF8PROC_HANGUL_VBASE = 0x1161;
enum UTF8PROC_HANGUL_TBASE = 0x11A7;
enum UTF8PROC_HANGUL_LCOUNT = 19;
enum UTF8PROC_HANGUL_VCOUNT = 21;
enum UTF8PROC_HANGUL_TCOUNT = 28;
enum UTF8PROC_HANGUL_NCOUNT = 588;
enum UTF8PROC_HANGUL_SCOUNT = 11172;
/* END is exclusive */
enum UTF8PROC_HANGUL_L_START  = 0x1100;
enum UTF8PROC_HANGUL_L_END    = 0x115A;
enum UTF8PROC_HANGUL_L_FILLER = 0x115F;
enum UTF8PROC_HANGUL_V_START  = 0x1160;
enum UTF8PROC_HANGUL_V_END    = 0x11A3;
enum UTF8PROC_HANGUL_T_START  = 0x11A8;
enum UTF8PROC_HANGUL_T_END    = 0x11FA;
enum UTF8PROC_HANGUL_S_START  = 0xAC00;
enum UTF8PROC_HANGUL_S_END    = 0xD7A4;

@nogc nothrow:

string utf8proc_version() {
    enum ret = UTF8PROC_VERSION_MAJOR.stringof ~ "." ~ UTF8PROC_VERSION_MINOR.stringof ~ "." ~ UTF8PROC_VERSION_PATCH.stringof;
    return ret;
}

string utf8proc_unicode_version() {
    return "13.0.0";
}

string utf8proc_errmsg(utf8proc_ssize_t errcode) {
    switch (errcode) {
        case UTF8PROC_ERROR_NOMEM:
            return "Memory for processing UTF-8 data could not be allocated.";
        case UTF8PROC_ERROR_OVERFLOW:
            return "UTF-8 string is too long to be processed.";
        case UTF8PROC_ERROR_INVALIDUTF8:
            return "Invalid UTF-8 string";
        case UTF8PROC_ERROR_NOTASSIGNED:
            return "Unassigned Unicode code point found in UTF-8 string.";
        case UTF8PROC_ERROR_INVALIDOPTS:
            return "Invalid options for UTF-8 processing chosen.";
        default:
            return "An unknown error occurred while processing UTF-8 data.";
    }
}

static bool utf_cont(T)(T ch) {
    return (((ch) & 0xc0) == 0x80);
}

utf8proc_ssize_t utf8proc_iterate(
    utf8proc_uint8_t *str, utf8proc_ssize_t strlen, utf8proc_int32_t *dst
) {
    utf8proc_uint32_t uc;
    
    *dst = -1;
    if (!strlen) return 0;
    const utf8proc_uint8_t *end = str + ((strlen < 0) ? 4 : strlen);
    uc = *str++;
    if (uc < 0x80) {
        *dst = uc;
        return 1;
    }
    // Must be between 0xc2 and 0xf4 inclusive to be valid
    if ((uc - 0xc2) > (0xf4-0xc2)) return UTF8PROC_ERROR_INVALIDUTF8;
    if (uc < 0xe0) {         // 2-byte sequence
        // Must have valid continuation character
        if (str >= end || !utf_cont(*str)) return UTF8PROC_ERROR_INVALIDUTF8;
        *dst = ((uc & 0x1f)<<6) | (*str & 0x3f);
        return 2;
    }
    if (uc < 0xf0) {        // 3-byte sequence
        if ((str + 1 >= end) || !utf_cont(*str) || !utf_cont(str[1]))
        return UTF8PROC_ERROR_INVALIDUTF8;
        // Check for surrogate chars
        if (uc == 0xed && *str > 0x9f)
            return UTF8PROC_ERROR_INVALIDUTF8;
        uc = ((uc & 0xf)<<12) | ((*str & 0x3f)<<6) | (str[1] & 0x3f);
        if (uc < 0x800)
            return UTF8PROC_ERROR_INVALIDUTF8;
        *dst = uc;
        return 3;
    }
    // 4-byte sequence
    // Must have 3 valid continuation characters
    if ((str + 2 >= end) || !utf_cont(*str) || !utf_cont(str[1]) || !utf_cont(str[2]))
        return UTF8PROC_ERROR_INVALIDUTF8;
    // Make sure in correct range (0x10000 - 0x10ffff)
    if (uc == 0xf0) {
    if (*str < 0x90) return UTF8PROC_ERROR_INVALIDUTF8;
    } else if (uc == 0xf4) {
    if (*str > 0x8f) return UTF8PROC_ERROR_INVALIDUTF8;
    }
    *dst = ((uc & 7)<<18) | ((*str & 0x3f)<<12) | ((str[1] & 0x3f)<<6) | (str[2] & 0x3f);
    return 4;
}

utf8proc_bool utf8proc_codepoint_valid(utf8proc_int32_t uc) {
    return ((cast(utf8proc_uint32_t)uc)-0xd800 > 0x07ff) && (cast(utf8proc_uint32_t)uc < 0x110000);
}

utf8proc_ssize_t utf8proc_encode_char(utf8proc_int32_t uc, utf8proc_uint8_t *dst) {
    if (uc < 0x00) {
        return 0;
    } else if (uc < 0x80) {
        dst[0] = cast(utf8proc_uint8_t) uc;
        return 1;
    } else if (uc < 0x800) {
        dst[0] = cast(utf8proc_uint8_t)(0xC0 + (uc >> 6));
        dst[1] = cast(utf8proc_uint8_t)(0x80 + (uc & 0x3F));
        return 2;
    // Note: we allow encoding 0xd800-0xdfff here, so as not to change
    // the API, however, these are actually invalid in UTF-8
    } else if (uc < 0x10000) {
        dst[0] = cast(utf8proc_uint8_t)(0xE0 + (uc >> 12));
        dst[1] = cast(utf8proc_uint8_t)(0x80 + ((uc >> 6) & 0x3F));
        dst[2] = cast(utf8proc_uint8_t)(0x80 + (uc & 0x3F));
        return 3;
    } else if (uc < 0x110000) {
        dst[0] = cast(utf8proc_uint8_t)(0xF0 + (uc >> 18));
        dst[1] = cast(utf8proc_uint8_t)(0x80 + ((uc >> 12) & 0x3F));
        dst[2] = cast(utf8proc_uint8_t)(0x80 + ((uc >> 6) & 0x3F));
        dst[3] = cast(utf8proc_uint8_t)(0x80 + (uc & 0x3F));
        return 4;
    } else return 0;
}

/* internal version used for inserting 0xff bytes between graphemes */
static utf8proc_ssize_t charbound_encode_char(utf8proc_int32_t uc, utf8proc_uint8_t *dst) {
    if (uc < 0x00) {
        if (uc == -1) { /* internal value used for grapheme breaks */
        dst[0] = cast(utf8proc_uint8_t)0xFF;
        return 1;
        }
        return 0;
    } else if (uc < 0x80) {
        dst[0] = cast(utf8proc_uint8_t)uc;
        return 1;
    } else if (uc < 0x800) {
        dst[0] = cast(utf8proc_uint8_t)(0xC0 + (uc >> 6));
        dst[1] = cast(utf8proc_uint8_t)(0x80 + (uc & 0x3F));
        return 2;
    } else if (uc < 0x10000) {
        dst[0] = cast(utf8proc_uint8_t)(0xE0 + (uc >> 12));
        dst[1] = cast(utf8proc_uint8_t)(0x80 + ((uc >> 6) & 0x3F));
        dst[2] = cast(utf8proc_uint8_t)(0x80 + (uc & 0x3F));
        return 3;
    } else if (uc < 0x110000) {
        dst[0] = cast(utf8proc_uint8_t)(0xF0 + (uc >> 18));
        dst[1] = cast(utf8proc_uint8_t)(0x80 + ((uc >> 12) & 0x3F));
        dst[2] = cast(utf8proc_uint8_t)(0x80 + ((uc >> 6) & 0x3F));
        dst[3] = cast(utf8proc_uint8_t)(0x80 + (uc & 0x3F));
        return 4;
    } else return 0;
}

/* internal "unsafe" version that does not check whether uc is in range */
static const(utf8proc_property_t)* unsafe_get_property(utf8proc_int32_t uc) {
  /* ASSERT: uc >= 0 && uc < 0x110000 */
  return &utf8proc_properties[0] + (
    utf8proc_stage2table[
      (utf8proc_stage1table[uc >> 8] + (uc & 0xFF))
    ]
  );
}

const(utf8proc_property_t)* utf8proc_get_property(utf8proc_int32_t uc) {
  return uc < 0 || uc >= 0x110000 ? &utf8proc_properties[0] : unsafe_get_property(uc);
}

/* return whether there is a grapheme break between boundclasses lbc and tbc
   (according to the definition of extended grapheme clusters)

  Rule numbering refers to TR29 Version 29 (Unicode 9.0.0):
  http://www.unicode.org/reports/tr29/tr29-29.html

  CAVEATS:
   Please note that evaluation of GB10 (grapheme breaks between emoji zwj sequences)
   and GB 12/13 (regional indicator code points) require knowledge of previous characters
   and are thus not handled by this function. This may result in an incorrect break before
   an E_Modifier class codepoint and an incorrectly missing break between two
   REGIONAL_INDICATOR class code points if such support does not exist in the caller.

   See the special support in grapheme_break_extended, for required bookkeeping by the caller.
*/
static utf8proc_bool grapheme_break_simple(int lbc, int tbc) {
  return
    (lbc == UTF8PROC_BOUNDCLASS_START) ? _true :       // GB1
    (lbc == UTF8PROC_BOUNDCLASS_CR &&                 // GB3
     tbc == UTF8PROC_BOUNDCLASS_LF) ? _false :         // ---
    (lbc >= UTF8PROC_BOUNDCLASS_CR && lbc <= UTF8PROC_BOUNDCLASS_CONTROL) ? _true :  // GB4
    (tbc >= UTF8PROC_BOUNDCLASS_CR && tbc <= UTF8PROC_BOUNDCLASS_CONTROL) ? _true :  // GB5
    (lbc == UTF8PROC_BOUNDCLASS_L &&                  // GB6
     (tbc == UTF8PROC_BOUNDCLASS_L ||                 // ---
      tbc == UTF8PROC_BOUNDCLASS_V ||                 // ---
      tbc == UTF8PROC_BOUNDCLASS_LV ||                // ---
      tbc == UTF8PROC_BOUNDCLASS_LVT)) ? _false :      // ---
    ((lbc == UTF8PROC_BOUNDCLASS_LV ||                // GB7
      lbc == UTF8PROC_BOUNDCLASS_V) &&                // ---
     (tbc == UTF8PROC_BOUNDCLASS_V ||                 // ---
      tbc == UTF8PROC_BOUNDCLASS_T)) ? _false :        // ---
    ((lbc == UTF8PROC_BOUNDCLASS_LVT ||               // GB8
      lbc == UTF8PROC_BOUNDCLASS_T) &&                // ---
     tbc == UTF8PROC_BOUNDCLASS_T) ? _false :          // ---
    (tbc == UTF8PROC_BOUNDCLASS_EXTEND ||             // GB9
     tbc == UTF8PROC_BOUNDCLASS_ZWJ ||                // ---
     tbc == UTF8PROC_BOUNDCLASS_SPACINGMARK ||        // GB9a
     lbc == UTF8PROC_BOUNDCLASS_PREPEND) ? _false :    // GB9b
    (lbc == UTF8PROC_BOUNDCLASS_E_ZWG &&              // GB11 (requires additional handling below)
     tbc == UTF8PROC_BOUNDCLASS_EXTENDED_PICTOGRAPHIC) ? _false : // ----
    (lbc == UTF8PROC_BOUNDCLASS_REGIONAL_INDICATOR &&          // GB12/13 (requires additional handling below)
     tbc == UTF8PROC_BOUNDCLASS_REGIONAL_INDICATOR) ? _false :  // ----
    _true; // GB999
}

static utf8proc_bool grapheme_break_extended(int lbc, int tbc, utf8proc_int32_t *state)
{
  int lbc_override = ((state && *state != UTF8PROC_BOUNDCLASS_START)
                      ? *state : lbc);
  utf8proc_bool break_permitted = grapheme_break_simple(lbc_override, tbc);
  if (state) {
    // Special support for GB 12/13 made possible by GB999. After two RI
    // class codepoints we want to force a break. Do this by resetting the
    // second RI's bound class to UTF8PROC_BOUNDCLASS_OTHER, to force a break
    // after that character according to GB999 (unless of course such a break is
    // forbidden by a different rule such as GB9).
    if (*state == tbc && tbc == UTF8PROC_BOUNDCLASS_REGIONAL_INDICATOR)
      *state = UTF8PROC_BOUNDCLASS_OTHER;
    // Special support for GB11 (emoji extend* zwj / emoji)
    else if (*state == UTF8PROC_BOUNDCLASS_EXTENDED_PICTOGRAPHIC) {
      if (tbc == UTF8PROC_BOUNDCLASS_EXTEND) // fold EXTEND codepoints into emoji
        *state = UTF8PROC_BOUNDCLASS_EXTENDED_PICTOGRAPHIC;
      else if (tbc == UTF8PROC_BOUNDCLASS_ZWJ)
        *state = UTF8PROC_BOUNDCLASS_E_ZWG; // state to record emoji+zwg combo
      else
        *state = tbc;
    }
    else
      *state = tbc;
  }
  return break_permitted;
}

utf8proc_bool utf8proc_grapheme_break_stateful(
    utf8proc_int32_t c1, utf8proc_int32_t c2, utf8proc_int32_t *state) {

  return grapheme_break_extended(utf8proc_get_property(c1).boundclass,
                                 utf8proc_get_property(c2).boundclass,
                                 state);
}

utf8proc_bool utf8proc_grapheme_break(
    utf8proc_int32_t c1, utf8proc_int32_t c2) {
  return utf8proc_grapheme_break_stateful(c1, c2, null);
}

static utf8proc_int32_t seqindex_decode_entry( utf8proc_uint16_t **entry)
{
  utf8proc_int32_t entry_cp = **entry;
  if ((entry_cp & 0xF800) == 0xD800) {
    *entry = *entry + 1;
    entry_cp = ((entry_cp & 0x03FF) << 10) | (**entry & 0x03FF);
    entry_cp += 0x10000;
  }
  return entry_cp;
}

static utf8proc_int32_t seqindex_decode_index(const utf8proc_uint32_t seqindex)
{
  utf8proc_uint16_t *entry = &utf8proc_sequences[seqindex];
  return seqindex_decode_entry(&entry);
}

static utf8proc_ssize_t seqindex_write_char_decomposed(utf8proc_uint16_t seqindex, utf8proc_int32_t *dst, utf8proc_ssize_t bufsize, utf8proc_option_t options, int *last_boundclass) {
  utf8proc_ssize_t written = 0;
  utf8proc_uint16_t *entry = &utf8proc_sequences[seqindex & 0x1FFF];
  int len = seqindex >> 13;
  if (len >= 7) {
    len = *entry;
    entry++;
  }
  for (; len >= 0; entry++, len--) {
    utf8proc_int32_t entry_cp = seqindex_decode_entry(&entry);

    written += utf8proc_decompose_char(entry_cp, dst+written,
      (bufsize > written) ? (bufsize - written) : 0, options,
    last_boundclass);
    if (written < 0) return UTF8PROC_ERROR_OVERFLOW;
  }
  return written;
}

utf8proc_int32_t utf8proc_tolower(utf8proc_int32_t c)
{
  utf8proc_int32_t cl = utf8proc_get_property(c).lowercase_seqindex;
  return cl != UINT16_MAX ? seqindex_decode_index(cl) : c;
}

utf8proc_int32_t utf8proc_toupper(utf8proc_int32_t c)
{
  utf8proc_int32_t cu = utf8proc_get_property(c).uppercase_seqindex;
  return cu != UINT16_MAX ? seqindex_decode_index(cu) : c;
}

utf8proc_int32_t utf8proc_totitle(utf8proc_int32_t c)
{
  utf8proc_int32_t cu = utf8proc_get_property(c).titlecase_seqindex;
  return cu != UINT16_MAX ? seqindex_decode_index(cu) : c;
}

/* return a character width analogous to wcwidth (except portable and
   hopefully less buggy than most system wcwidth functions). */
int utf8proc_charwidth(utf8proc_int32_t c) {
  return utf8proc_get_property(c).charwidth;
}

utf8proc_category_t utf8proc_category(utf8proc_int32_t c) {
  return utf8proc_get_property(c).category;
}

static const(char)[3][30] s__ = ["Cn","Lu","Ll","Lt","Lm","Lo","Mn","Mc","Me","Nd","Nl","No","Pc","Pd","Ps","Pe","Pi","Pf","Po","Sm","Sc","Sk","So","Zs","Zl","Zp","Cc","Cf","Cs","Co"];

const(char)* utf8proc_category_string(utf8proc_int32_t c) {
  
  return s__[utf8proc_category(c)].ptr;
}

utf8proc_ssize_t utf8proc_decompose_char(utf8proc_int32_t uc, utf8proc_int32_t *dst, utf8proc_ssize_t bufsize, utf8proc_option_t options, int *last_boundclass) {
  utf8proc_property_t *property;
  utf8proc_propval_t category;
  utf8proc_int32_t hangul_sindex;
  if (uc < 0 || uc >= 0x110000) return UTF8PROC_ERROR_NOTASSIGNED;
  property = cast(utf8proc_property_t*)unsafe_get_property(uc);
  category = property.category;
  hangul_sindex = uc - UTF8PROC_HANGUL_SBASE;
  if (options & (UTF8PROC_COMPOSE|UTF8PROC_DECOMPOSE)) {
    if (hangul_sindex >= 0 && hangul_sindex < UTF8PROC_HANGUL_SCOUNT) {
      utf8proc_int32_t hangul_tindex;
      if (bufsize >= 1) {
        dst[0] = UTF8PROC_HANGUL_LBASE +
          hangul_sindex / UTF8PROC_HANGUL_NCOUNT;
        if (bufsize >= 2) dst[1] = UTF8PROC_HANGUL_VBASE +
          (hangul_sindex % UTF8PROC_HANGUL_NCOUNT) / UTF8PROC_HANGUL_TCOUNT;
      }
      hangul_tindex = hangul_sindex % UTF8PROC_HANGUL_TCOUNT;
      if (!hangul_tindex) return 2;
      if (bufsize >= 3) dst[2] = UTF8PROC_HANGUL_TBASE + hangul_tindex;
      return 3;
    }
  }
  if (options & UTF8PROC_REJECTNA) {
    if (!category) return UTF8PROC_ERROR_NOTASSIGNED;
  }
  if (options & UTF8PROC_IGNORE) {
    if (property.ignorable) return 0;
  }
  if (options & UTF8PROC_STRIPNA) {
    if (!category) return 0;
  }
  if (options & UTF8PROC_LUMP) {
    if (category == UTF8PROC_CATEGORY_ZS) return utf8proc_decompose_char(0x0020, dst, bufsize, options & ~UTF8PROC_LUMP, last_boundclass);
    if (uc == 0x2018 || uc == 0x2019 || uc == 0x02BC || uc == 0x02C8)
      return utf8proc_decompose_char(0x0027, dst, bufsize, options & ~UTF8PROC_LUMP, last_boundclass);
    if (category == UTF8PROC_CATEGORY_PD || uc == 0x2212)
      return utf8proc_decompose_char(0x002D, dst, bufsize, options & ~UTF8PROC_LUMP, last_boundclass);
    if (uc == 0x2044 || uc == 0x2215) return utf8proc_decompose_char(0x002F, dst, bufsize, options & ~UTF8PROC_LUMP, last_boundclass);
    if (uc == 0x2236) return utf8proc_decompose_char(0x003A, dst, bufsize, options & ~UTF8PROC_LUMP, last_boundclass);
    if (uc == 0x2039 || uc == 0x2329 || uc == 0x3008)
      return utf8proc_decompose_char(0x003C, dst, bufsize, options & ~UTF8PROC_LUMP, last_boundclass);
    if (uc == 0x203A || uc == 0x232A || uc == 0x3009)
      return utf8proc_decompose_char(0x003E, dst, bufsize, options & ~UTF8PROC_LUMP, last_boundclass);
    if (uc == 0x2216) return utf8proc_decompose_char(0x005C, dst, bufsize, options & ~UTF8PROC_LUMP, last_boundclass);
    if (uc == 0x02C4 || uc == 0x02C6 || uc == 0x2038 || uc == 0x2303)
      return utf8proc_decompose_char(0x005E, dst, bufsize, options & ~UTF8PROC_LUMP, last_boundclass);
    if (category == UTF8PROC_CATEGORY_PC || uc == 0x02CD)
      return utf8proc_decompose_char(0x005F, dst, bufsize, options & ~UTF8PROC_LUMP, last_boundclass);
    if (uc == 0x02CB) utf8proc_decompose_char(0x0060, dst, bufsize, options & ~UTF8PROC_LUMP, last_boundclass);
    if (uc == 0x2223) utf8proc_decompose_char(0x007C, dst, bufsize, options & ~UTF8PROC_LUMP, last_boundclass);
    if (uc == 0x223C) utf8proc_decompose_char(0x007E, dst, bufsize, options & ~UTF8PROC_LUMP, last_boundclass);
    if ((options & UTF8PROC_NLF2LS) && (options & UTF8PROC_NLF2PS)) {
      if (category == UTF8PROC_CATEGORY_ZL ||
          category == UTF8PROC_CATEGORY_ZP)
        utf8proc_decompose_char(0x000A, dst, bufsize, options & ~UTF8PROC_LUMP, last_boundclass);
    }
  }
  if (options & UTF8PROC_STRIPMARK) {
    if (category == UTF8PROC_CATEGORY_MN ||
      category == UTF8PROC_CATEGORY_MC ||
      category == UTF8PROC_CATEGORY_ME) return 0;
  }
  if (options & UTF8PROC_CASEFOLD) {
    if (property.casefold_seqindex != UINT16_MAX) {
      return seqindex_write_char_decomposed(property.casefold_seqindex, dst, bufsize, options, last_boundclass);
    }
  }
  if (options & (UTF8PROC_COMPOSE|UTF8PROC_DECOMPOSE)) {
    if (property.decomp_seqindex != UINT16_MAX &&
        (!property.decomp_type || (options & UTF8PROC_COMPAT))) {
      return seqindex_write_char_decomposed(property.decomp_seqindex, dst, bufsize, options, last_boundclass);
    }
  }
  if (options & UTF8PROC_CHARBOUND) {
    utf8proc_bool boundary;
    int tbc = property.boundclass;
    boundary = grapheme_break_extended(*last_boundclass, tbc, last_boundclass);
    if (boundary) {
      if (bufsize >= 1) dst[0] = -1; /* sentinel value for grapheme break */
      if (bufsize >= 2) dst[1] = uc;
      return 2;
    }
  }
  if (bufsize >= 1) *dst = uc;
  return 1;
}

utf8proc_ssize_t utf8proc_decompose(
  const utf8proc_uint8_t *str, utf8proc_ssize_t strlen,
  utf8proc_int32_t *buffer, utf8proc_ssize_t bufsize, utf8proc_option_t options
) {
    return utf8proc_decompose_custom(str, strlen, buffer, bufsize, options, null, null);
}

utf8proc_ssize_t utf8proc_decompose_custom(
  const utf8proc_uint8_t *str, utf8proc_ssize_t strlen,
  utf8proc_int32_t *buffer, utf8proc_ssize_t bufsize, utf8proc_option_t options,
  utf8proc_custom_func custom_func, void *custom_data
) {
  /* strlen will be ignored, if UTF8PROC_NULLTERM is set in options */
  utf8proc_ssize_t wpos = 0;
  if ((options & UTF8PROC_COMPOSE) && (options & UTF8PROC_DECOMPOSE))
    return UTF8PROC_ERROR_INVALIDOPTS;
  if ((options & UTF8PROC_STRIPMARK) &&
      !(options & UTF8PROC_COMPOSE) && !(options & UTF8PROC_DECOMPOSE))
    return UTF8PROC_ERROR_INVALIDOPTS;
  {
    utf8proc_int32_t uc;
    utf8proc_ssize_t rpos = 0;
    utf8proc_ssize_t decomp_result;
    int boundclass = UTF8PROC_BOUNDCLASS_START;
    while (1) {
      if (options & UTF8PROC_NULLTERM) {
        rpos += utf8proc_iterate(cast(ubyte*)(str + rpos), -1, &uc);
        /* checking of return value is not necessary,
           as 'uc' is < 0 in case of error */
        if (uc < 0) return UTF8PROC_ERROR_INVALIDUTF8;
        if (rpos < 0) return UTF8PROC_ERROR_OVERFLOW;
        if (uc == 0) break;
      } else {
        if (rpos >= strlen) break;
        rpos += utf8proc_iterate(cast(ubyte*)(str + rpos), strlen - rpos, &uc);
        if (uc < 0) return UTF8PROC_ERROR_INVALIDUTF8;
      }
      if (custom_func != null) {
        uc = custom_func(uc, custom_data);   /* user-specified custom mapping */
      }
      decomp_result = utf8proc_decompose_char(
        uc, buffer + wpos, (bufsize > wpos) ? (bufsize - wpos) : 0, options,
        &boundclass
      );
      if (decomp_result < 0) return decomp_result;
      wpos += decomp_result;
      /* prohibiting integer overflows due to too long strings: */
      if (wpos < 0 ||
          wpos > cast(utf8proc_ssize_t)(SSIZE_MAX/(utf8proc_int32_t.sizeof)/2))
        return UTF8PROC_ERROR_OVERFLOW;
    }
  }
  if ((options & (UTF8PROC_COMPOSE|UTF8PROC_DECOMPOSE)) && bufsize >= wpos) {
    utf8proc_ssize_t pos = 0;
    while (pos < wpos-1) {
      utf8proc_int32_t uc1, uc2;
      utf8proc_property_t* property1, property2;
      uc1 = buffer[pos];
      uc2 = buffer[pos+1];
      property1 = cast(utf8proc_property_struct*)unsafe_get_property(uc1);
      property2 = cast(utf8proc_property_struct*)unsafe_get_property(uc2);
      if (property1.combining_class > property2.combining_class &&
          property2.combining_class > 0) {
        buffer[pos] = uc2;
        buffer[pos+1] = uc1;
        if (pos > 0) pos--; else pos++;
      } else {
        pos++;
      }
    }
  }
  return wpos;
}

utf8proc_ssize_t utf8proc_normalize_utf32(utf8proc_int32_t *buffer, utf8proc_ssize_t length, utf8proc_option_t options) {
  /* UTF8PROC_NULLTERM option will be ignored, 'length' is never ignored */
  if (options & (UTF8PROC_NLF2LS | UTF8PROC_NLF2PS | UTF8PROC_STRIPCC)) {
    utf8proc_ssize_t rpos;
    utf8proc_ssize_t wpos = 0;
    utf8proc_int32_t uc;
    for (rpos = 0; rpos < length; rpos++) {
      uc = buffer[rpos];
      if (uc == 0x000D && rpos < length-1 && buffer[rpos+1] == 0x000A) rpos++;
      if (uc == 0x000A || uc == 0x000D || uc == 0x0085 ||
          ((options & UTF8PROC_STRIPCC) && (uc == 0x000B || uc == 0x000C))) {
        if (options & UTF8PROC_NLF2LS) {
          if (options & UTF8PROC_NLF2PS) {
            buffer[wpos++] = 0x000A;
          } else {
            buffer[wpos++] = 0x2028;
          }
        } else {
          if (options & UTF8PROC_NLF2PS) {
            buffer[wpos++] = 0x2029;
          } else {
            buffer[wpos++] = 0x0020;
          }
        }
      } else if ((options & UTF8PROC_STRIPCC) &&
          (uc < 0x0020 || (uc >= 0x007F && uc < 0x00A0))) {
        if (uc == 0x0009) buffer[wpos++] = 0x0020;
      } else {
        buffer[wpos++] = uc;
      }
    }
    length = wpos;
  }
  if (options & UTF8PROC_COMPOSE) {
    utf8proc_int32_t *starter = null;
    utf8proc_int32_t current_char;
    utf8proc_property_t* starter_property = null, current_property;
    utf8proc_propval_t max_combining_class = -1;
    utf8proc_ssize_t rpos;
    utf8proc_ssize_t wpos = 0;
    utf8proc_int32_t composition;
    for (rpos = 0; rpos < length; rpos++) {
      current_char = buffer[rpos];
      current_property = cast(utf8proc_property_struct*)unsafe_get_property(current_char);
      if (starter && current_property.combining_class > max_combining_class) {
        /* combination perhaps possible */
        utf8proc_int32_t hangul_lindex;
        utf8proc_int32_t hangul_sindex;
        hangul_lindex = *starter - UTF8PROC_HANGUL_LBASE;
        if (hangul_lindex >= 0 && hangul_lindex < UTF8PROC_HANGUL_LCOUNT) {
          utf8proc_int32_t hangul_vindex;
          hangul_vindex = current_char - UTF8PROC_HANGUL_VBASE;
          if (hangul_vindex >= 0 && hangul_vindex < UTF8PROC_HANGUL_VCOUNT) {
            *starter = UTF8PROC_HANGUL_SBASE +
              (hangul_lindex * UTF8PROC_HANGUL_VCOUNT + hangul_vindex) *
              UTF8PROC_HANGUL_TCOUNT;
            starter_property = null;
            continue;
          }
        }
        hangul_sindex = *starter - UTF8PROC_HANGUL_SBASE;
        if (hangul_sindex >= 0 && hangul_sindex < UTF8PROC_HANGUL_SCOUNT &&
            (hangul_sindex % UTF8PROC_HANGUL_TCOUNT) == 0) {
          utf8proc_int32_t hangul_tindex;
          hangul_tindex = current_char - UTF8PROC_HANGUL_TBASE;
          if (hangul_tindex >= 0 && hangul_tindex < UTF8PROC_HANGUL_TCOUNT) {
            *starter += hangul_tindex;
            starter_property = null;
            continue;
          }
        }
        if (!starter_property) {
          starter_property = cast(utf8proc_property_struct*)unsafe_get_property(*starter);
        }
        if (starter_property.comb_index < 0x8000 &&
            current_property.comb_index != UINT16_MAX &&
            current_property.comb_index >= 0x8000) {
          int sidx = starter_property.comb_index;
          int idx = current_property.comb_index & 0x3FFF;
          if (idx >= utf8proc_combinations[sidx] && idx <= utf8proc_combinations[sidx + 1] ) {
            idx += sidx + 2 - utf8proc_combinations[sidx];
            if (current_property.comb_index & 0x4000) {
              composition = (utf8proc_combinations[idx] << 16) | utf8proc_combinations[idx+1];
            } else
              composition = utf8proc_combinations[idx];

            if (composition > 0 && (!(options & UTF8PROC_STABLE) ||
                !(unsafe_get_property(composition).comp_exclusion))) {
              *starter = composition;
              starter_property = null;
              continue;
            }
          }
        }
      }
      buffer[wpos] = current_char;
      if (current_property.combining_class) {
        if (current_property.combining_class > max_combining_class) {
          max_combining_class = current_property.combining_class;
        }
      } else {
        starter = buffer + wpos;
        starter_property = null;
        max_combining_class = -1;
      }
      wpos++;
    }
    length = wpos;
  }
  return length;
}

utf8proc_ssize_t utf8proc_reencode(utf8proc_int32_t *buffer, utf8proc_ssize_t length, utf8proc_option_t options) {
  /* UTF8PROC_NULLTERM option will be ignored, 'length' is never ignored
     ASSERT: 'buffer' has one spare byte of free space at the end! */
  length = utf8proc_normalize_utf32(buffer, length, options);
  if (length < 0) return length;
  {
    utf8proc_ssize_t rpos, wpos = 0;
    utf8proc_int32_t uc;
    if (options & UTF8PROC_CHARBOUND) {
        for (rpos = 0; rpos < length; rpos++) {
            uc = buffer[rpos];
            wpos += charbound_encode_char(uc, (cast(utf8proc_uint8_t *)buffer) + wpos);
        }
    } else {
        for (rpos = 0; rpos < length; rpos++) {
            uc = buffer[rpos];
            wpos += utf8proc_encode_char(uc, (cast(utf8proc_uint8_t *)buffer) + wpos);
        }
    }
    (cast(utf8proc_uint8_t *)buffer)[wpos] = 0;
    return wpos;
  }
}

utf8proc_ssize_t utf8proc_map(
  const utf8proc_uint8_t *str, utf8proc_ssize_t strlen, utf8proc_uint8_t **dstptr, utf8proc_option_t options
) {
    return utf8proc_map_custom(str, strlen, dstptr, options, null, null);
}

utf8proc_ssize_t utf8proc_map_custom(
  const utf8proc_uint8_t *str, utf8proc_ssize_t strlen, utf8proc_uint8_t **dstptr, utf8proc_option_t options,
  utf8proc_custom_func custom_func, void *custom_data
) {
  utf8proc_int32_t *buffer;
  utf8proc_ssize_t result;
  *dstptr = null;
  result = utf8proc_decompose_custom(str, strlen, null, 0, options, custom_func, custom_data);
  if (result < 0) return result;
  buffer = cast(utf8proc_int32_t *) malloc(result * utf8proc_int32_t.sizeof + 1);
  if (!buffer) return UTF8PROC_ERROR_NOMEM;
  result = utf8proc_decompose_custom(str, strlen, buffer, result, options, custom_func, custom_data);
  if (result < 0) {
    free(buffer);
    return result;
  }
  result = utf8proc_reencode(buffer, result, options);
  if (result < 0) {
    free(buffer);
    return result;
  }
  {
    utf8proc_int32_t *newptr;
    newptr = cast(utf8proc_int32_t *) realloc(buffer, cast(size_t)result+1);
    if (newptr) buffer = newptr;
  }
  *dstptr = cast(utf8proc_uint8_t *)buffer;
  return result;
}

utf8proc_uint8_t *utf8proc_NFD(const utf8proc_uint8_t *str) {
  utf8proc_uint8_t *retval;
  utf8proc_map(str, 0, &retval, UTF8PROC_NULLTERM | UTF8PROC_STABLE |
    UTF8PROC_DECOMPOSE);
  return retval;
}

utf8proc_uint8_t *utf8proc_NFC(const utf8proc_uint8_t *str) {
  utf8proc_uint8_t *retval;
  utf8proc_map(str, 0, &retval, UTF8PROC_NULLTERM | UTF8PROC_STABLE |
    UTF8PROC_COMPOSE);
  return retval;
}

utf8proc_uint8_t *utf8proc_NFKD(const utf8proc_uint8_t *str) {
  utf8proc_uint8_t *retval;
  utf8proc_map(str, 0, &retval, UTF8PROC_NULLTERM | UTF8PROC_STABLE |
    UTF8PROC_DECOMPOSE | UTF8PROC_COMPAT);
  return retval;
}

utf8proc_uint8_t *utf8proc_NFKC(const utf8proc_uint8_t *str) {
  utf8proc_uint8_t *retval;
  utf8proc_map(str, 0, &retval, UTF8PROC_NULLTERM | UTF8PROC_STABLE |
    UTF8PROC_COMPOSE | UTF8PROC_COMPAT);
  return retval;
}

utf8proc_uint8_t *utf8proc_NFKC_Casefold(const utf8proc_uint8_t *str) {
  utf8proc_uint8_t *retval;
  utf8proc_map(str, 0, &retval, UTF8PROC_NULLTERM | UTF8PROC_STABLE |
    UTF8PROC_COMPOSE | UTF8PROC_COMPAT | UTF8PROC_CASEFOLD | UTF8PROC_IGNORE);
  return retval;
}