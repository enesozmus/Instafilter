//
//  ContentView.swift
//  Instafilter
//
//  Created by enesozmus on 25.03.2024.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import StoreKit
import SwiftUI

struct ContentView: View {
    // → Initially the user won’t have selected an image, so we’ll represent that using an @State optional image property.
    @State private var processedImage: Image?
    // → An “Intensity” slider that will affect how strongly we apply our Core Image filters, stored as a value from 0.0 to 1.0.
    @State private var filterIntensity = 0.5
    @State private var filterRadius = 100.0
    @State private var filterScale = 5.0
    // → In order to bring this project to life, we need to let the user select a photo from their library, then display it in ContentView.
    @State private var selectedItem: PhotosPickerItem?
    // → a confirmation dialog
    @State private var showingFilters = false
    
    @AppStorage("filterCount") var filterCount = 0
    @Environment(\.requestReview) var requestReview
    
    // → As for the filter, we’ll be using CIFilter.sepiaTone() as our default but because we’ll make it flexible later we’ll make the filter use @State so it can be changed.
    @State private var currentFilter: CIFilter = CIFilter.sepiaTone()
    // → A Core Image context is an object that’s responsible for rendering a CIImage to a CGImage.
    // → an object for converting the recipe for an image into an actual series of pixels we can work with.
    let context = CIContext()
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                // → It will be one of two things:
                // → If we have an image already selected then we should show it,
                // → otherwise we'll display a simple ContentUnavailableView so users know that space isn't just accidentally blank:
                PhotosPicker(selection: $selectedItem) {
                    if let processedImage {
                        processedImage
                            .resizable()
                            .scaledToFit()
                    } else {
                        ContentUnavailableView("No picture", systemImage: "photo.badge.plus", description: Text("Tap to import a photo"))
                    }
                }
                // → We need a method that will be called when the an image has been selected.
                .onChange(of: selectedItem, loadImage)
                
                Spacer()
                
                // ...
                HStack {
                    Text("Intensity")
                    Slider(value: $filterIntensity)
                        .onChange(of: filterIntensity, applyProcessing)
                        .disabled(processedImage == nil)
                }
                .padding(.vertical)
                
                HStack {
                    Text("Radius")
                    
                    Slider(value: $filterRadius, in: 0...200)
                        .onChange(of: filterRadius, applyProcessing)
                        .disabled(processedImage == nil)
                }
                .padding(.vertical)
                
                HStack {
                    Text("Scale")
                    
                    Slider(value: $filterScale, in: 0...10)
                        .onChange(of: filterScale, applyProcessing)
                        .disabled(processedImage == nil)
                }
                .padding(.vertical)
                // ...
                
                HStack {
                    Button("Change Filter", action: changeFilter)
                        .disabled(processedImage == nil)
                    
                    Spacer()
                    
                    if let processedImage {
                        ShareLink(item: processedImage, preview: SharePreview("Instafilter image", image: processedImage))
                    }
                }
            }
            .padding([.horizontal, .bottom])
            .navigationTitle("Instafilter")
            .confirmationDialog("Select a filter", isPresented: $showingFilters) {
                Button("Crystallize") { setFilter(CIFilter.crystallize() )}
                Button("Edges") { setFilter(CIFilter.edges() )}
                Button("Gaussian Blur") { setFilter(CIFilter.gaussianBlur() )}
                Button("Pixellate") { setFilter(CIFilter.pixellate() )}
                Button("Sepia Tone") { setFilter(CIFilter.sepiaTone() )}
                Button("Unsharp Mask") { setFilter(CIFilter.unsharpMask() )}
                Button("Vignette") { setFilter(CIFilter.vignette() )}
                Button("Pointillize") { setFilter(.pointillize()) }
                Button("Dither") { setFilter(.dither()) }
                Button("Disc Blur") { setFilter(.discBlur()) }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    // ...
    // functions
    func changeFilter() {
        showingFilters = true
    }
    
    func loadImage() {
        // → Here we need to kind of bolt those two things together: we can't load a simple SwiftUI image because they can't be fed into Core Image, so instead we load a pure Data object and convert that to a UIImage.
        Task {
            guard let imageData = try await selectedItem?.loadTransferable(type: Data.self) else { return }
            guard let inputImage = UIImage(data: imageData) else { return }
            
            let beginImage = CIImage(image: inputImage)
            currentFilter.setValue(beginImage, forKey: kCIInputImageKey)
            applyProcessing()
        }
    }
    
    func applyProcessing() {
        let inputKeys = currentFilter.inputKeys
        
        if inputKeys.contains(kCIInputIntensityKey) {
            currentFilter.setValue(filterIntensity, forKey: kCIInputIntensityKey)
        }
        if inputKeys.contains(kCIInputRadiusKey) {
            currentFilter.setValue(filterRadius, forKey: kCIInputRadiusKey)
        }
        if inputKeys.contains(kCIInputScaleKey) {
            currentFilter.setValue(filterScale, forKey: kCIInputScaleKey)
        }
        
        // → That means it will read the output image back from the filter, ask our CIContext to render it, then place the result into our processedImage property so it’s visible on-screen.
        guard let outputImage = currentFilter.outputImage else { return }
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return }
        
        let uiImage = UIImage(cgImage: cgImage)
        processedImage = Image(uiImage: uiImage)
    }
    
    @MainActor func setFilter(_ filter: CIFilter) {
        currentFilter = filter
        loadImage()
        
        filterCount += 1
        
        if filterCount >= 20 {
            requestReview()
        }
    }
}

#Preview {
    ContentView()
}
