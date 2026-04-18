/**
 * After Part No / 品番 is found at (partNoRow, labelCol), read Part Name / 品名 / 部品名 from:
 *   - row above (common FM: Part Name then Part No), or
 *   - row below (alternate layout).
 * Value uses the same wide scan to the right as Part No (labelCol+1 .. valEnd).
 */

function readPartNameNearPartNoRow(ws, range, partNoRow, labelCol, valEnd, partNo, deps) {
  const { cellText, stripLeadingColonValue, normalizePartName, XLSX } = deps;
  const enc = (r, c) => XLSX.utils.encode_cell({ r, c });

  const tryRow = (R) => {
    if (R < range.s.r || R > range.e.r) return null;
    const lbl = cellText(ws[enc(R, labelCol)]?.v)
      .replace(/\s+/g, " ")
      .trim();
    if (!/^part\s*name$/i.test(lbl) && !/^品名$/i.test(lbl) && !/^部品名$/i.test(lbl)) return null;
    for (let CC = labelCol + 1; CC <= valEnd; CC++) {
      const cellRaw = stripLeadingColonValue(cellText(ws[enc(R, CC)]?.v));
      if (cellRaw) return normalizePartName(cellRaw, partNo);
    }
    return null;
  };

  const up = tryRow(partNoRow - 1);
  if (up) return up;
  const down = tryRow(partNoRow + 1);
  if (down) return down;
  return partNo;
}

module.exports = { readPartNameNearPartNoRow };
