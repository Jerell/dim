pub const TokenType = enum {
    Number,
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
