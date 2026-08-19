//
//  SheetRoute.swift
//

import Foundation

enum SheetRoute: Identifiable, Hashable {
    case quickSave
    case filters
    case sort
    case newCollection
    case itemMenu(UUID)
    case editItem(UUID)

    var id: String {
        switch self {
        case .quickSave: "quickSave"
        case .filters: "filters"
        case .sort: "sort"
        case .newCollection: "newCollection"
        case .itemMenu(let id): "itemMenu-\(id.uuidString)"
        case .editItem(let id): "editItem-\(id.uuidString)"
        }
    }
}
