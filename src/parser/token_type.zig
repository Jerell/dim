pub const TokenType = enum {
    Number,
    Superscript,
    Dot,
    Comma,
    // units
    Identifier,
    // commands
    List,
    Show,
    Clear,
    All,

    //operations
    Plus,
    Minus,
    Star,
    Slash,
    Caret,
    // marks a quantity as a difference: "Δ20 °C", "delta 20 °C"
    Delta,
    LParen,
    RParen,
    // for unit conversion
    As,
    Colon,

    // comparison
    Bang,
    BangEqual,
    Equal,
    EqualEqual,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,
    Or,
    And,

    Eof,
};
