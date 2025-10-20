//
//  RSSParser.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-09.
//


//  RSSParser.swift
//  Gameshelf

import Foundation

enum RSSParser {
    static func parse(data: Data) -> [NewsItem] {
        let delegate = RSSDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.items
    }

    // MARK: Delegate
    final class RSSDelegate: NSObject, XMLParserDelegate {
        var items: [NewsItem] = []
        private var currentElement = ""
        private var currentTitle = ""
        private var currentLink  = ""
        private var currentSource = ""
        private var currentPubDate = ""
        private var currentImage = ""
        private var currentContent = ""
        private var currentCategories: [String] = []
        private var currentCategoryBuffer = ""

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes dict: [String : String] = [:]) {
            currentElement = elementName
            if currentElement.lowercased() == "category" || currentElement.lowercased() == "dc:subject" {
                currentCategoryBuffer = ""
            }
            if elementName == "item" || elementName == "entry" {
                currentTitle = ""; currentLink = ""; currentSource = ""
                currentPubDate = ""; currentImage = ""; currentContent = ""
                currentCategories = []
                currentCategoryBuffer = ""
            }
            let lname = elementName.lowercased()
            if lname == "media:content" || lname == "media:thumbnail" {
                if let u = dict["url"], !u.isEmpty { currentImage = u }
            } else if lname == "enclosure" {
                if let type = dict["type"], type.contains("image"),
                   let u = dict["url"], !u.isEmpty { currentImage = u }
            } else if lname == "link" {
                if let href = dict["href"], !href.isEmpty {
                    if let rel = dict["rel"], rel == "alternate" { currentLink = href }
                    else if currentLink.isEmpty { currentLink = href }
                }
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            switch currentElement.lowercased() {
            case "title": currentTitle += string
            case "link": currentLink += string
            case "source": currentSource += string
            case "pubdate", "updated", "published": currentPubDate += string
            case "content:encoded", "description": currentContent += string
            case "category", "dc:subject":
                currentCategoryBuffer += string
            default: break
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let lname = elementName.lowercased()
            if lname == "category" || lname == "dc:subject" {
                let tag = currentCategoryBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !tag.isEmpty { currentCategories.append(tag) }
                currentCategoryBuffer = ""
            }
            if elementName == "item" || elementName == "entry" {
                if currentImage.isEmpty, let img = RSSParser.extractFirstImageURL(fromHTML: currentContent) {
                    currentImage = img
                }
                let src = currentSource.isEmpty
                    ? (URL(string: currentLink)?.host?.replacingOccurrences(of: "www.", with: "") ?? "")
                    : currentSource
                let date = RFC822DateFormatter.date(from: currentPubDate)
                    ?? ISO8601DateFormatter().date(from: currentPubDate)

                let kind = RSSParser.inferKind(title: currentTitle, source: src, link: currentLink, categories: currentCategories, contentHTML: currentContent)

                items.append(NewsItem(
                    title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    source: src,
                    link: URL(string: currentLink.trimmingCharacters(in: .whitespacesAndNewlines)),
                    published: date,
                    image: URL(string: currentImage.trimmingCharacters(in: .whitespacesAndNewlines)),
                    tags: currentCategories,
                    kind: kind
                ))
            }
            currentElement = ""
        }
    }

    // Fångar första <img src="..."> ur HTML
    static func extractFirstImageURL(fromHTML html: String) -> String? {
        guard let img = html.range(of: "<img", options: [.caseInsensitive]) else { return nil }
        let tail = html[img.lowerBound...]
        if let src = tail.range(of: "src=\"", options: [.caseInsensitive]) {
            let start = src.upperBound
            if let end = tail[start...].firstIndex(of: "\"") { return String(tail[start..<end]) }
        }
        return nil
    }

    // Heuristic classification based on title, URL, categories and HTML content
    static func inferKind(title: String, source: String, link: String, categories: [String], contentHTML: String) -> NewsKind {
        let titleLC   = title.lowercased()
        let linkLC    = link.lowercased()
        let sourceLC  = source.lowercased()
        let catsLC    = categories.map { $0.lowercased() }
        let haystack  = (titleLC + " " + linkLC + " " + catsLC.joined(separator: " ") + " " + contentHTML.lowercased())

        func has(_ words: [String]) -> Bool { words.contains { haystack.contains($0) } }
        func catsContain(_ words: [String]) -> Bool { catsLC.contains { c in words.contains { c.contains($0) } } }

        func containsWord(_ text: String, _ word: String) -> Bool {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return (try? NSRegularExpression(pattern: pattern, options: .caseInsensitive))?
                .firstMatch(in: text, options: [], range: range) != nil
        }

        // Negative contexts that should *not* count as a review unless URL clearly points to a review page
        let negativeReviewPhrases = [
            "roundup", "round-up", "scores", "review scores", "score roundup",
            "patch notes", "update notes", "update:", "hotfix", "changelog"
        ]

        // --- Preview / hands-on --- (checked before Review to avoid substring matches)
        let previewTokens = [
            "preview", "hands-on", "hands on",
            "first look", "first-look",
            "impressions", "first impressions", "förhandstitt"
        ]
        if has(previewTokens) || catsContain(["preview", "previews"]) ||
            linkLC.contains("/preview/") || linkLC.contains("/previews/") || linkLC.contains("/hands-on/") {
            return .preview
        }

        // --- Strong, early review signals (use word boundaries to avoid matching 'preview') ---
        let reviewWords = ["review", "recension", "anmeldelse", "recensione"]
        let urlIsReview = linkLC.contains("/review/") || linkLC.contains("/reviews/") || linkLC.contains("/recension/") || linkLC.contains("/tests/")
        let strongTitleReview = titleLC.hasPrefix("review:") || titleLC.hasPrefix("recension:") || titleLC.hasSuffix(" review")
        let hasNegativeReviewContext = has(negativeReviewPhrases)

        // Accept immediately when URL or strong title indicates a review
        if urlIsReview || strongTitleReview {
            return .review
        }

        // Fallback (stricter): require the word "review" (or localized) in the **title** with word boundaries,
        // and no negative context such as "scores", "roundup", "patch notes", etc.
        let titleHasReviewWord = reviewWords.contains { containsWord(titleLC, $0) }
        if titleHasReviewWord && !hasNegativeReviewContext {
            return .review
        }

        // --- Guides / How-to ---
        let guideWords = ["guide", "walkthrough"]
        let hasGuideWord = guideWords.contains { containsWord(haystack, $0) }
        let guideTokens = [
            "tips ", "how to", "how-to", "explained", "build guide", "tier list", "best build"
        ]
        if hasGuideWord || has(guideTokens) || catsContain(["guide", "guides"]) ||
            linkLC.contains("/guide/") || linkLC.contains("/guides/") || linkLC.contains("/how-to/") || linkLC.contains("/walkthrough/") {
            return .guide
        }

        // --- Opinion / Editorial ---
        let opinionWords = ["opinion", "editorial", "commentary", "op-ed", "op ed", "kr\u{00F6}nika"]
        if opinionWords.contains(where: { containsWord(haystack, $0) }) || catsContain(["opinion", "editorial"]) {
            return .opinion
        }

        // --- Interview ---
        if has(["interview", "q&a"]) || catsContain(["interview"]) || linkLC.contains("/interview/") {
            return .interview
        }

        // --- Video / Trailer ---
        let videoTokens = ["trailer", "gameplay", "watch the", "video:", "livestream"]
        if has(videoTokens) || catsContain(["video"]) || linkLC.contains("/trailer/") {
            return .video
        }

        // --- Deals ---
        let dealTokens = ["deal", "reapris", "sale", "discount", "offer", "bundle", "free weekend"]
        if has(dealTokens) || catsContain(["deal", "deals"]) || linkLC.contains("/deals/") {
            return .deal
        }

        // --- Feature / Long reads ---
        let featureWords = ["feature"]
        if featureWords.contains(where: { containsWord(haystack, $0) }) || has(["in-depth", "retrospective", "history of", "behind the scenes", "ranking"]) || catsContain(["feature"]) {
            return .feature
        }

        // Source-specific hints (some outlets prefix titles)
        if sourceLC.contains("nintendolife.com") || sourceLC.contains("pushsquare.com") || sourceLC.contains("purexbox.com") {
            if titleLC.hasPrefix("review:") { return .review }
            if titleLC.hasPrefix("preview:") { return .preview }
        }

        // Default
        return .news
    }
}

// Datumformat för RSS/Atom
enum RFC822DateFormatter {
    static func date(from string: String) -> Date? {
        let fmts = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz"
        ]
        for f in fmts {
            let df = DateFormatter()
            df.locale = .init(identifier: "en_US_POSIX")
            df.dateFormat = f
            if let d = df.date(from: string) { return d }
        }
        return nil
    }
}
