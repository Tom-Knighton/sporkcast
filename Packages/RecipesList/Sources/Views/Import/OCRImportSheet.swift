//
//  OCRImportSheet.swift
//  RecipesList
//
//  Created by Codex on 27/03/2026.
//

import SwiftUI
import PhotosUI
import UIKit

struct OCRImportSheet: View {
    let onImportText: (String) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var extractedText: String = ""
    @State private var isExtracting: Bool = false
    @State private var isCameraPresented: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label("Choose Photo", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            isCameraPresented = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 12))
                    }

                    if isExtracting {
                        ProgressView("Extracting text...")
                    }

                    TextEditor(text: $extractedText)
                        .frame(minHeight: 220)
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                        )

                    Text("Only extracted text is used for API fallback; raw images are not uploaded.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Import From Photo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImportText(extractedText)
                        dismiss()
                    }
                    .disabled(extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $isCameraPresented) {
                CameraImagePicker { image in
                    Task {
                        await processImage(image)
                    }
                }
            }
            .onChange(of: selectedItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await processImage(image)
                    }
                }
            }
        }
    }

    @MainActor
    private func processImage(_ image: UIImage) async {
        selectedImage = image
        isExtracting = true
        defer { isExtracting = false }
        extractedText = await OCRTextExtractor.extract(from: image)
    }
}
