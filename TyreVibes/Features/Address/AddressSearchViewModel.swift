import Foundation
import Combine

class AddressSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var addressSuggestions = [AddressSuggestion]()
    @Published var isLoading = false
    @Published var error: Error?

    private var addressService = AddressService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.isLoading = true
                self?.error = nil
            })
            .flatMap { [unowned self] query -> AnyPublisher<[AddressSuggestion], Never> in
                guard !query.isEmpty else {
                    return Just([]).eraseToAnyPublisher()
                }

                return Future<[AddressSuggestion], Error> { promise in
                    self.addressService.findPlace(query: query) { result in
                        promise(result)
                    }
                }
                .catch { [weak self] error -> Just<[AddressSuggestion]> in
                    DispatchQueue.main.async {
                        self?.error = error
                    }
                    return Just([])
                }
                .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] suggestions in
                self?.isLoading = false
                self?.addressSuggestions = suggestions
            })
            .store(in: &cancellables)
    }

    func clearError() {
        self.error = nil
    }
}