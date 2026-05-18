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

    func deleteRecords(_ ids: [UUID]) {
        for id in ids {
            PhotoStorageService.shared.deleteRecord(id)
        }
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
