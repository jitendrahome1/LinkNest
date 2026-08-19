//
//  String+HTMLEntities.swift
//  Decodes named entities (&amp;, &quot;, …) and general numeric character
//  references (&#xHHHH; / &#NNNN;) — needed for non-Latin titles (Hindi,
//  emoji, etc.) scraped from Open Graph tags, and for `&amp;`-encoded query
//  strings inside og:image URLs, which otherwise resolve to the wrong resource.
//

import Foundation

extension String {
    var decodingHTMLEntities: String {
        var result = Self.replaceNumericEntities(in: self, isHex: true)
        result = Self.replaceNumericEntities(in: result, isHex: false)
        let named: [(String, String)] = [
            ("&quot;", "\""), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " "), ("&amp;", "&")
        ]
        for (entity, replacement) in named {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }

    /// Single linear pass over the immutable original string, appending
    /// decoded characters as we go. A repeated-global-replace approach (find
    /// each match, then `replacingOccurrences` on the whole string) silently
    /// drops later replacements when the same entity value repeats — each
    /// global replace invalidates the remaining matches' assumptions about
    /// what's still in the string.
    private static func replaceNumericEntities(in text: String, isHex: Bool) -> String {
        let pattern = isHex ? "&#x([0-9A-Fa-f]+);" : "&#([0-9]+);"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return text }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return text }

        var result = ""
        var lastEnd = 0
        for match in matches {
            let range = match.range(at: 0)
            result += ns.substring(with: NSRange(location: lastEnd, length: range.location - lastEnd))
            let numString = ns.substring(with: match.range(at: 1))
            if let code = UInt32(numString, radix: isHex ? 16 : 10), let scalar = Unicode.Scalar(code) {
                result.append(Character(scalar))
            } else {
                result += ns.substring(with: range)
            }
            lastEnd = range.location + range.length
        }
        result += ns.substring(with: NSRange(location: lastEnd, length: ns.length - lastEnd))
        return result
    }
}
