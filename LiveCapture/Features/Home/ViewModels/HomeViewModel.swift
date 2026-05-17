import Foundation
import Combine
import UIKit

final class HomeViewModel: ObservableObject {
    @Published private(set) var records: [PhotoRecord] = []
    private var cancellables: Set<AnyCancellable> = []

    init() {
        PhotoStorageService.shared.recordsPublisher
            .receive(on: DispatchQueue.main)
            .map { $0.sorted { $0.creationDate > $1.creationDate } }
            .sink { [weak self] records in
                self?.records = records
            }
            .store(in: &cancellables)
    }

    func deleteRecord(_ id: UUID) {
        PhotoStorageService.shared.deleteRecord(id)
    }

    func toggleShared(_ id: UUID) {
        PhotoStorageService.shared.toggleShared(for: id)
    }

    func thumbnail(for id: UUID) -> UIImage? {
        PhotoStorageService.shared.thumbnail(for: id)
    }
}
