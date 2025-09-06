pub const TokenType = enum {
    Number,
    Dot,
    Comma,
    Underscore,
    // units
    Identifier,

    //operations
    Plus,
    Minus,
    Star,
    Slash,
    Caret,
    LParen,
    RParen,
    // for unit conversion
    In,

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
