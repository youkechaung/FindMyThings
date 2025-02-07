import SwiftUI

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var locationManager = LocationManager.shared
    @Binding var selectedLocation: Location?
    @State private var showingAddLocation = false
    @State private var newLocationName = ""
    @State private var currentParent: Location?
    
    var body: some View {
        NavigationStack {
            List {
                if let parent = currentParent {
                    Button {
                        currentParent = locationManager.getLocation(by: parent.parent ?? UUID())
                    } label: {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("返回上级")
                        }
                    }
                }
                
                ForEach(currentParent == nil ? locationManager.getRootLocations() : locationManager.getChildren(of: currentParent!)) { location in
                    HStack {
                        Button {
                            if locationManager.getChildren(of: location).isEmpty {
                                selectedLocation = location
                                dismiss()
                            } else {
                                currentParent = location
                            }
                        } label: {
                            HStack {
                                Text(location.name)
                                Spacer()
                                if !locationManager.getChildren(of: location).isEmpty {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(currentParent?.name ?? "选择位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddLocation = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("添加位置", isPresented: $showingAddLocation) {
                TextField("位置名称", text: $newLocationName)
                Button("取消", role: .cancel) { }
                Button("添加") {
                    if !newLocationName.isEmpty {
                        let location = locationManager.addLocation(newLocationName, parent: currentParent?.id)
                        if locationManager.getRootLocations().count == 1 {
                            selectedLocation = location
                            dismiss()
                        }
                        newLocationName = ""
                    }
                }
            }
        }
    }
}
