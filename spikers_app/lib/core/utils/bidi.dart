/// Bidirectional-text helpers (Premium Pass Phase 7).
///
/// User-generated content (names, announcement titles/bodies) can freely mix
/// Arabic and English. Without isolation, an embedded opposite-direction run
/// re-orders the characters around it and "shreds" the sentence. Wrapping the
/// value in a Unicode *first-strong isolate* lets each piece resolve its own
/// direction without leaking into the surrounding layout.
library;

/// Wraps [text] in FSI (U+2068) / PDI (U+2069) so it renders with its own
/// first-strong direction, isolated from surrounding text. Safe to apply to
/// any [Text] content, including ellipsized single-line labels.
String bidiIsolate(String text) => '\u2068$text\u2069';
