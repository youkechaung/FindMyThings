//
//  ContentView.swift
//  找得到
//
//  Created by chloe on 2025/2/7.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var itemManager = ItemManager()
    @State private var showingAddItem = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchBar(text: $searchText)
                    .padding()
                
                List {
                    ForEach(itemManager.searchItems(query: searchText)) { item in
                        HStack(spacing: 12) {
                            if let imageData = item.imageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.headline)
                                Text(item.location)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                if item.isInUse {
                                    Text("请放回原处，谢谢")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            Spacer()
                            
                            Button {
                                itemManager.toggleItemUse(item)
                            } label: {
                                Text(item.isInUse ? "归还" : "使用")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(item.isInUse ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                                    .foregroundColor(item.isInUse ? .red : .blue)
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            let item = itemManager.items[index]
                            itemManager.deleteItem(item)
                        }
                    }
                }
            }
            .navigationTitle("找得到")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView(itemManager: itemManager)
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("搜索物品...", text: $text)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    ContentView()
}
