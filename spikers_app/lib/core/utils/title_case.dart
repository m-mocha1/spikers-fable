/// Display-time casing for user-typed names (locations, venues) that often
/// arrive all-lowercase ("sport hall jerusalem").
///
/// Only the first letter of each word is uppercased — the rest of the word is
/// left untouched so intentional casing ("TLV Arena") survives, and scripts
/// without letter case (Arabic) pass through unchanged. Never write the
/// result back to Firestore; the stored value stays exactly as the user
/// typed it.
extension TitleCase on String {
  String toTitleCase() => split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
