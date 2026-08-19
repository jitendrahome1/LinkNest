//
//  DeepLinkHandler.swift
//  linknest://content/{id} · linknest://collection/{id} · linknest://search/{query}
//

import Foundation

@MainActor
struct DeepLinkHandler {
    let router: AppRouter
    let container: AppContainer

    func handle(_ url: URL) {
        guard url.scheme == "linknest" else { return }
        let parts = [url.host].compactMap { $0 } + url.pathComponents.filter { $0 != "/" }
        guard let kind = parts.first else { return }

        switch kind {
        case "content":
            if parts.count > 1, let id = UUID(uuidString: parts[1]),
               let item = container.contentRepository.item(id: id) {
                router.switchTab(.home)
                router.push(.viewer(for: item))
            }
        case "collection":
            if parts.count > 1, let id = UUID(uuidString: parts[1]) {
                router.switchTab(.collections)
                router.push(.collectionDetail(id))
            }
        case "search":
            router.switchTab(.home)
            router.push(.search)
        case "save":
            router.sheet = .quickSave
        default:
            break
        }
    }
}
