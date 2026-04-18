/**
 * Legacy: normalizes "CS F0B-0071" style file base names when deriving Part No from the file name.
 * Bundled import scripts now read Part No from the sheet only; this module is kept for ad-hoc reuse or copy-paste.
 *
 * - "CS F0B-0071" / "cs 3B012006" → tail after whitespace following CS
 * - "CS_F0B-0071" → tail after CS_
 * - "CSF0B-0071" (no space) → "F0B-0071" when remainder looks like a part number
 */

function baseNameForPartFromFileName(base) {
  const b = String(base || "")
    .trim()
    .replace(/^~\$/, "");
  if (!b) return b;

  const mSpace = b.match(/^CS\s+(.+)$/i);
  if (mSpace && mSpace[1] && String(mSpace[1]).trim()) {
    return String(mSpace[1]).trim();
  }
  const mUnder = b.match(/^CS_\s*(.+)$/i);
  if (mUnder && mUnder[1] && String(mUnder[1]).trim()) {
    return String(mUnder[1]).trim();
  }

  if (/^CS[A-Z0-9._\-/]/i.test(b) && b.length >= 6) {
    const tail = b.slice(2);
    if (tail.length >= 4 && /^[A-Z0-9._\-/]+$/i.test(tail)) return tail;
  }

  return b;
}

module.exports = { baseNameForPartFromFileName };
