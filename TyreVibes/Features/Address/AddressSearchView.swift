import SwiftUI

struct AddressSearchView: View {
    @StateObject private var viewModel = AddressSearchViewModel()

    var body: some View {
        NavigationView {
            VStack {
                TextField("Search for an address...", text: $viewModel.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                if viewModel.isLoading {
                    
                } else if let error = viewModel.error {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                } else {
                    List(viewModel.addressSuggestions) { suggestion in
                        VStack(alignment: .leading) {
                            Text(suggestion.street).font(.headline)
                            Text("\(suggestion.city), \(suggestion.province) \(suggestion.zipcode)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Address Search")
        }
    }
}

struct AddressSearchView_Previews: PreviewProvider {
    static var previews: some View {
        AddressSearchView()
    }
}
