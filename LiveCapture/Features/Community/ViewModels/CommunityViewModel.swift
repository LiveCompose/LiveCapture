import Foundation
import Combine
import UIKit

final class CommunityViewModel: ObservableObject {
    @Published private(set) var sharedRecords: [PhotoRecord] = []
    private var cancellables: Set<AnyCancellable> = []

    init() {
        PhotoStorageService.shared.recordsPublisher
            .receive(on: DispatchQueue.main)
            .map { $0.filter { $0.isShared }.sorted { $0.creationDate > $1.creationDate } }
            .sink { [weak self] records in
                self?.sharedRecords = records
            }
            .store(in: &cancellables)
    }

    func removeFromCommunity(_ id: UUID) {
        PhotoStorageService.shared.toggleShared(for: id)
    }

    func thumbnail(for id: UUID) -> UIImage? {
        PhotoStorageService.shared.thumbnail(for: id)
    }

    func fullPhoto(for id: UUID) -> UIImage? {
        guard let url = PhotoStorageService.shared.photoURL(for: id),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
