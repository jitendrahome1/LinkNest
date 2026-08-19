//
//  MockSeeder.swift
//  Seeds the store with the demo library from the approved prototype
//  so the app launches in a realistic state. Runs once per install.
//

import Foundation
import SwiftData

enum MockSeeder {
    private static let seededKey = "linknest.hasSeededMockData"

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        defer { UserDefaults.standard.set(true, forKey: seededKey) }

        // Collections (order + colors from the prototype)
        let ios = ContentCollection(name: "iOS Development", colorHex: 0x4A50DB, sortIndex: 0)
        let ai = ContentCollection(name: "AI & Machine Learning", colorHex: 0x7A3FD1, sortIndex: 1)
        let career = ContentCollection(name: "Career", colorHex: 0x0E8A8A, sortIndex: 2)
        let finance = ContentCollection(name: "Finance", colorHex: 0x2E9E5B, sortIndex: 3)
        let design = ContentCollection(name: "Design", colorHex: 0xC74B78, sortIndex: 4)
        let learning = ContentCollection(name: "Learning", colorHex: 0xC4880F, sortIndex: 5)
        let travel = ContentCollection(name: "Travel", colorHex: 0x3577D9, sortIndex: 6)
        let inspiration = ContentCollection(name: "Inspiration", colorHex: 0x8A6BE0, sortIndex: 7)
        [ios, ai, career, finance, design, learning, travel, inspiration].forEach { context.insert($0) }

        // Tags
        var tags: [String: Tag] = [:]
        for name in ["SwiftUI", "Swift", "AI", "Architecture", "Design", "Career", "Finance", "Learning",
                     "UX", "LLM", "SwiftData", "Typography", "Figma", "Hiring", "Investing", "Deep Learning",
                     "Systems", "Engineering", "Travel", "Budget", "Books", "Focus", "Japan", "Productivity"] {
            let tag = Tag(name: name)
            tags[name] = tag
            context.insert(tag)
        }

        func ago(_ hours: Double) -> Date { Date.now.addingTimeInterval(-hours * 3600) }

        // ContentItems — 19 entries mirroring the prototype library
        let items: [ContentItem] = [
            .init(url: "https://youtube.com/watch?v=8kZq3xB", title: "SwiftUI Architecture for Large Apps", thumbnailHue: 255, platform: .youtube, contentType: .video, creatorName: "John Appleseed", duration: "28:14", createdAt: ago(2), lastViewedAt: ago(26), isFavorite: true, collection: ios, tags: [tags["SwiftUI"]!, tags["Architecture"]!]),
            .init(url: "https://youtube.com/watch?v=dEs1gN", title: "Designing Calm Interfaces", thumbnailHue: 20, platform: .youtube, contentType: .video, creatorName: "Design Everyday", duration: "14:02", createdAt: ago(5), isWatchLater: true, collection: design, tags: [tags["Design"]!, tags["UX"]!]),
            .init(url: "https://youtube.com/watch?v=lLm5wRk", title: "How LLMs Actually Work", thumbnailHue: 300, platform: .youtube, contentType: .video, creatorName: "Ada Lab", duration: "41:30", createdAt: ago(26), lastViewedAt: ago(50), notes: "Great mental model for attention around 18:00.", isFavorite: true, isWatchLater: true, collection: ai, tags: [tags["AI"]!, tags["LLM"]!]),
            .init(url: "https://x.com/swift_owl/status/1728431", title: "Thread: 12 SwiftData pitfalls in production", thumbnailHue: 230, platform: .x, contentType: .post, creatorName: "@swift_owl", createdAt: ago(28), isFavorite: true, collection: ios, tags: [tags["SwiftData"]!, tags["Swift"]!]),
            .init(url: "https://instagram.com/p/Cx8aQ2n", title: "10 typography rules I wish I knew earlier", thumbnailHue: 340, platform: .instagram, contentType: .post, creatorName: "@type.wise", createdAt: ago(50), isFavorite: true, collection: design, tags: [tags["Typography"]!, tags["Design"]!]),
            .init(url: "https://youtube.com/watch?v=f1gMa2s", title: "Figma to SwiftUI Workflow", thumbnailHue: 270, platform: .youtube, contentType: .video, creatorName: "Maya Codes", duration: "22:47", createdAt: ago(52), isWatchLater: true, collection: ios, tags: [tags["SwiftUI"]!, tags["Figma"]!]),
            .init(url: "https://linkedin.com/posts/priya-sharma-hiring", title: "What I learned interviewing 40 iOS engineers", thumbnailHue: 210, platform: .linkedin, contentType: .article, creatorName: "Priya Sharma", createdAt: ago(74), lastViewedAt: ago(26), collection: career, tags: [tags["Career"]!, tags["Hiring"]!]),
            .init(url: "https://youtube.com/watch?v=1nDexFnd", title: "Index Funds Explained in 12 Minutes", thumbnailHue: 150, platform: .youtube, contentType: .video, creatorName: "Plain Finance", duration: "12:08", createdAt: ago(76), collection: finance, tags: [tags["Investing"]!]),
            .init(url: "https://thegradient.pub/attention", title: "A Guide to Attention Mechanisms", thumbnailHue: 290, platform: .website, contentType: .article, creatorName: "The Gradient", createdAt: ago(98), isWatchLater: true, collection: ai, tags: [tags["AI"]!, tags["Deep Learning"]!]),
            .init(url: "https://uxdesign.cc/spacing-psychology", title: "The Psychology of Spacing in UI", thumbnailHue: 35, platform: .website, contentType: .article, creatorName: "UX Collective", createdAt: ago(122), collection: design, tags: [tags["Design"]!, tags["UX"]!]),
            .init(url: "https://x.com/worknotes/status/1720045", title: "The best career advice is boring", thumbnailHue: 190, platform: .x, contentType: .post, creatorName: "@worknotes", createdAt: ago(124), collection: career, tags: [tags["Career"]!]),
            .init(url: "https://linkedin.com/posts/daniel-kim-rag", title: "RAG is not a moat — a systems view", thumbnailHue: 310, platform: .linkedin, contentType: .article, creatorName: "Daniel Kim", createdAt: ago(146), isFavorite: true, collection: ai, tags: [tags["AI"]!, tags["Systems"]!]),
            .init(url: "https://mcfunley.com/choose-boring-technology", title: "Choosing Boring Technology", thumbnailHue: 80, platform: .website, contentType: .article, creatorName: "Dan McKinley", createdAt: ago(170), lastViewedAt: ago(74), isFavorite: true, collection: learning, tags: [tags["Engineering"]!]),
            .init(url: "https://instagram.com/p/tokyo60", title: "Tokyo on $60 a day", thumbnailHue: 170, platform: .instagram, contentType: .post, creatorName: "@wander.frames", createdAt: ago(172), isWatchLater: true, collection: travel, tags: [tags["Travel"]!, tags["Budget"]!]),
            .init(url: "https://mrmoneynotes.com/ymoyl", title: "Your Money or Your Life — key takeaways", thumbnailHue: 140, platform: .website, contentType: .article, creatorName: "Mr. Money Notes", createdAt: ago(194), isFavorite: true, collection: finance, tags: [tags["Finance"]!, tags["Books"]!]),
            .init(url: "https://facebook.com/share/p/9aK2m", title: "Why side projects die", thumbnailHue: 60, platform: .facebook, contentType: .post, creatorName: "Builders Club", createdAt: ago(340), collection: career, tags: [tags["Career"]!, tags["Focus"]!]),
            .init(url: "https://fieldnotes.blog/kyoto-temples", title: "Kyoto's quiet temples: a walking route", thumbnailHue: 120, platform: .website, contentType: .article, creatorName: "Field Notes", createdAt: ago(342), collection: travel, tags: [tags["Travel"]!, tags["Japan"]!]),
            .init(url: "https://mindstack.blog/learning-to-learn", title: "Learning How to Learn, condensed", thumbnailHue: 100, platform: .website, contentType: .article, creatorName: "MindStack", createdAt: ago(344), isWatchLater: true, collection: learning, tags: [tags["Learning"]!]),
            .init(url: "https://instagram.com/p/devhabits", title: "Morning routines of focused engineers", thumbnailHue: 50, platform: .instagram, contentType: .post, creatorName: "@dev.habits", createdAt: ago(510), collection: career, tags: [tags["Productivity"]!]),

            // Real, directly-playable sample items for the video/PDF viewers.
            .init(url: "https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4", title: "Sample Clip — Flower", thumbnailHue: 205, platform: .website, contentType: .video, creatorName: "MDN Web Docs", duration: "0:10", createdAt: ago(1), collection: ios, tags: [tags["SwiftUI"]!]),
            .init(url: "https://mozilla.github.io/pdf.js/web/compressed.tracemonkey-pldi-09.pdf", title: "TraceMonkey: A JIT Compiler for JavaScript", thumbnailHue: 15, platform: .website, contentType: .pdf, creatorName: "Mozilla Research", createdAt: ago(3), collection: learning, tags: [tags["Engineering"]!])
        ]
        items.forEach { context.insert($0) }

        // Recent searches
        ["swiftui navigation", "attention mechanisms", "minimal portfolio"].enumerated().forEach { index, query in
            context.insert(SavedSearch(query: query, createdAt: ago(Double(index + 1) * 12)))
        }

        // Demo profile
        context.insert(UserProfile(name: "Maya Chen", email: "maya.chen@icloud.com"))

        try? context.save()
    }
}
