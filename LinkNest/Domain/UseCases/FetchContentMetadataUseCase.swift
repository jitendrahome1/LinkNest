//
//  FetchContentMetadataUseCase.swift
//

import Foundation

struct FetchContentMetadataUseCase {
    let metadata: any MetadataService

    func callAsFunction(url: String) async throws -> LinkMetadata {
        try await metadata.fetchMetadata(for: url)
    }
}
