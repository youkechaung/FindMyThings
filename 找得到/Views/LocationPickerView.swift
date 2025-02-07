import SwiftUI

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var locationManager = LocationManager.shared
    @Binding var selectedLocation: Location?
    @State private var showingAddLocation = false
    @State private var newLocationName = ""
    @State private var path: [Location] = []
    
    var body: some View {
        NavigationStack(path: $path) {
            LocationListView(
                currentLocation: nil,
                selectedLocation: $selectedLocation,
                path: $path,
                dismiss: dismiss
            )
            .navigationTitle("选择位置")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Location.self) { location in
                LocationListView(
                    currentLocation: location,
                    selectedLocation: $selectedLocation,
                    path: $path,
                    dismiss: dismiss
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LocationListView: View {
    let currentLocation: Location?
    @Binding var selectedLocation: Location?
    @Binding var path: [Location]
    let dismiss: DismissAction
    @ObservedObject var locationManager = LocationManager.shared
    @State private var showingAddLocation = false
    @State private var newLocationName = ""
    
    var body: some View {
        List {
            if let location = currentLocation {
                Section {
                    Button {
                        selectedLocation = location
                        dismiss()
                    } label: {
                        HStack {
                            Text("选择当前位置：\(location.name)")
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            Section {
                ForEach(currentLocation == nil ? locationManager.getRootLocations() : locationManager.getChildren(of: currentLocation!)) { location in
                    Button {
                        path.append(location)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(location.name)
                                if !locationManager.getChildren(of: location).isEmpty {
                                    Text("\(locationManager.getChildren(of: location).count) 个子位置")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            selectedLocation = location
                            dismiss()
                        } label: {
                            Label("选择", systemImage: "checkmark")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .leading) {
                        Button(role: .destructive) {
                            locationManager.deleteLocation(location)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            
            Section {
                Button {
                    showingAddLocation = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("添加新位置")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle(currentLocation?.name ?? "选择位置")
        .alert("添加位置", isPresented: $showingAddLocation) {
            TextField("位置名称", text: $newLocationName)
            Button("取消", role: .cancel) { }
            Button("添加") {
                if !newLocationName.isEmpty {
                    let location = locationManager.addLocation(newLocationName, parent: currentLocation?.id)
                    newLocationName = ""
                }
            }
        }
    }
}
