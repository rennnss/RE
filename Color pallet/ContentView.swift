//
//  ContentView.swift
//  Color pallet
//
//  Created by ren on 27/04/25.
//

import SwiftUI
import PhotosUI
import AVFoundation

struct ColorPalette: Identifiable, Codable {
    let id: UUID
    let colors: [Color]
    let date: Date
    
    // Add Codable conformance for Color
    enum CodingKeys: String, CodingKey {
        case id, date
        case red, green, blue
    }
    
    init(colors: [Color], date: Date) {
        self.id = UUID()
        self.colors = colors
        self.date = date
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        
        var colors: [Color] = []
        let redValues = try container.decode([Double].self, forKey: .red)
        let greenValues = try container.decode([Double].self, forKey: .green)
        let blueValues = try container.decode([Double].self, forKey: .blue)
        
        for i in 0..<redValues.count {
            colors.append(Color(red: redValues[i], green: greenValues[i], blue: blueValues[i]))
        }
        self.colors = colors
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        
        let redValues = colors.map { $0.components.red }
        let greenValues = colors.map { $0.components.green }
        let blueValues = colors.map { $0.components.blue }
        
        try container.encode(redValues, forKey: .red)
        try container.encode(greenValues, forKey: .green)
        try container.encode(blueValues, forKey: .blue)
    }
    
    var hexCodes: [String] {
        colors.map { color in
            let components = color.components
            return String(format: "#%02X%02X%02X",
                         Int(components.red * 255),
                         Int(components.green * 255),
                         Int(components.blue * 255))
        }
    }
    
    var rgbValues: [String] {
        colors.map { color in
            let components = color.components
            return String(format: "RGB(%d, %d, %d)",
                         Int(components.red * 255),
                         Int(components.green * 255),
                         Int(components.blue * 255))
        }
    }
}

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var colorPalette: [Color] = []
    @State private var savedPalettes: [ColorPalette] = []
    @State private var showingImagePicker = false
    @State private var showingSavedPalettes = false
    @State private var selectedColorIndex: Int?
    @State private var showingColorInfo = false
    @State private var colorCount: Int = 5
    @State private var samplingZone: Int = 0
    
    private let soundPlayer: AVAudioPlayer? = {
        guard let soundURL = Bundle.main.url(forResource: "click", withExtension: "mp3") else {
            print("Warning: Click sound file not found")
            return nil
        }
        do {
            return try AVAudioPlayer(contentsOf: soundURL)
        } catch {
            print("Error initializing sound player: \(error)")
            return nil
        }
    }()
    
    init() {
        // Load saved palettes from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "savedPalettes"),
           let decodedPalettes = try? JSONDecoder().decode([ColorPalette].self, from: data) {
            _savedPalettes = State(initialValue: decodedPalettes)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.black.opacity(0.95)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                            .clipped()
                            .cornerRadius(16)
                            .overlay(
                                LinearGradient(
                                    gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .padding(.horizontal, 16)
                    }
                    
                    if !colorPalette.isEmpty {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Number of Colors:")
                                    .foregroundColor(.white)
                                    .font(.headline)
                                Picker("", selection: $colorCount) {
                                    ForEach([3, 5, 7, 9], id: \.self) { count in
                                        Text("\(count)").tag(count)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 200)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                
                                Button(action: {
                                    playClickSound()
                                    if let image = selectedImage {
                                        generateColorPalette(from: image)
                                    }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(0..<colorPalette.count, id: \.self) { index in
                                        ColorRow(color: colorPalette[index], index: index)
                                            .onTapGesture {
                                                playClickSound()
                                                UIPasteboard.general.string = colorPalette[index].hexCode
                                                withAnimation {
                                                    selectedColorIndex = index
                                                    showingColorInfo = true
                                                }
                                            }
                                    }
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("Select an image to extract colors")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 0) {
                            // Import Image Section
                            VStack {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.2))
                            .onTapGesture {
                                playClickSound()
                                showingImagePicker = true
                            }
                            
                            // Save Palette Section
                            VStack {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.2))
                            .onTapGesture {
                                playClickSound()
                                if !colorPalette.isEmpty {
                                    let newPalette = ColorPalette(colors: colorPalette, date: Date())
                                    savedPalettes.append(newPalette)
                                    if let encoded = try? JSONEncoder().encode(savedPalettes) {
                                        UserDefaults.standard.set(encoded, forKey: "savedPalettes")
                                    }
                                }
                            }
                            
                            // View Saved Section
                            VStack {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.2))
                            .onTapGesture {
                                playClickSound()
                                showingSavedPalettes = true
                            }
                            
                            // Clear Saved Section
                            VStack {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.2))
                            .onTapGesture {
                                playClickSound()
                                savedPalettes.removeAll()
                                if let encoded = try? JSONEncoder().encode(savedPalettes) {
                                    UserDefaults.standard.set(encoded, forKey: "savedPalettes")
                                }
                            }
                        }
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        Color.clear
                            .overlay(
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(Color.gray.opacity(0.2)),
                                alignment: .top
                            )
                    )
                }
            }
            .navigationTitle("Re:Pallete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Re:Pallete")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage, onImageSelected: { image in
                    if let image = image {
                        generateColorPalette(from: image)
                    }
                })
            }
            .sheet(isPresented: $showingSavedPalettes) {
                SavedPalettesView(palettes: $savedPalettes)
            }
            .sheet(isPresented: $showingColorInfo) {
                if let index = selectedColorIndex {
                    ColorInfoView(color: colorPalette[index])
                }
            }
        }
    }
    
    private func generateColorPalette(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        let totalBytes = width * height * bytesPerPixel
        
        var rawData = [UInt8](repeating: 0, count: totalBytes)
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var colorCounts: [String: Int] = [:]
        let samplingRate = 10 // Sample every 10th pixel for performance
        
        // Calculate sampling zone based on the current zone
        let zoneHeight = height / 3
        let startY = (samplingZone % 3) * zoneHeight
        let endY = startY + zoneHeight
        
        for y in stride(from: startY, to: endY, by: samplingRate) {
            for x in stride(from: 0, to: width, by: samplingRate) {
                let offset = (y * width + x) * bytesPerPixel
                let r = rawData[offset]
                let g = rawData[offset + 1]
                let b = rawData[offset + 2]
                
                // Quantize colors to reduce the number of unique colors
                let quantizedR = (r / 32) * 32
                let quantizedG = (g / 32) * 32
                let quantizedB = (b / 32) * 32
                
                let colorKey = "\(quantizedR),\(quantizedG),\(quantizedB)"
                colorCounts[colorKey, default: 0] += 1
            }
        }
        
        // Sort colors by frequency and take the top N colors
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        let topColors = sortedColors.prefix(colorCount)
        
        colorPalette = topColors.compactMap { element in
            let components = element.key.split(separator: ",")
            guard components.count == 3,
                  let r = Double(components[0]),
                  let g = Double(components[1]),
                  let b = Double(components[2]) else {
                return nil
            }
            return Color(red: r / 255.0, green: g / 255.0, blue: b / 255.0)
        }
        
        // Increment sampling zone for next regeneration
        samplingZone = (samplingZone + 1) % 3
    }
    
    private func playClickSound() {
        soundPlayer?.play()
    }
}

struct ColorRow: View {
    let color: Color
    let index: Int
    @State private var isPressed = false
    @State private var showingCopiedFeedback = false
    
    private var textColor: Color {
        let components = color.components
        let brightness = (components.red * 299 + components.green * 587 + components.blue * 114) / 1000
        return brightness > 0.6 ? .black : .white
    }
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Color \(index + 1)")
                    .font(.headline)
                    .foregroundColor(textColor)
                
                Text(color.hexCode)
                    .font(.subheadline)
                    .foregroundColor(textColor.opacity(0.8))
            }
            
            Spacer()
            
            Image(systemName: "doc.on.doc")
                .font(.system(size: 20))
                .foregroundColor(textColor)
                .frame(width: 44, height: 44)
                .background(textColor.opacity(0.2))
                .clipShape(Circle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(color)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(textColor.opacity(0.1)),
            alignment: .bottom
        )
        .overlay(
            Group {
                if showingCopiedFeedback {
                    Text("Copied!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(20)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        )
        .onTapGesture {
            withAnimation {
                isPressed = true
                showingCopiedFeedback = true
            }
            UIPasteboard.general.string = color.hexCode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isPressed = false
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showingCopiedFeedback = false
                }
            }
        }
    }
}

struct ColorInfoView: View {
    let color: Color
    @Environment(\.dismiss) var dismiss
    @State private var showingCopiedFeedback = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 25) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(color)
                        .frame(height: 200)
                        .padding(.horizontal)
                        .shadow(radius: 5)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        ColorInfoRow(title: "Hex", value: color.hexCode)
                        ColorInfoRow(title: "RGB", value: color.rgbValue)
                        ColorInfoRow(title: "HSL", value: color.hslValue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    
                    Button(action: {
                        UIPasteboard.general.string = color.hexCode
                        withAnimation {
                            showingCopiedFeedback = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showingCopiedFeedback = false
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.headline)
                            Text("Copy Hex Code")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(15)
                        .shadow(radius: 3)
                    }
                    .padding(.horizontal)
                    .overlay(
                        Group {
                            if showingCopiedFeedback {
                                Text("Copied!")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.green)
                                    .cornerRadius(10)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    )
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Color Information")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct ColorInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
}

struct SavedPalettesView: View {
    @Binding var palettes: [ColorPalette]
    @Environment(\.dismiss) var dismiss
    @State private var selectedPalette: ColorPalette?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if palettes.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No saved palettes yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(palettes) { palette in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    ForEach(palette.colors, id: \.self) { color in
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(color)
                                            .frame(height: 30)
                                            .shadow(radius: 2)
                                    }
                                }
                                
                                Text(palette.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPalette = palette
                            }
                        }
                        .onDelete { indexSet in
                            palettes.remove(atOffsets: indexSet)
                            if let encoded = try? JSONEncoder().encode(palettes) {
                                UserDefaults.standard.set(encoded, forKey: "savedPalettes")
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Saved Palettes")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .sheet(item: $selectedPalette) { palette in
                ColorPaletteDetailView(palette: palette)
            }
        }
    }
}

struct ColorPaletteDetailView: View {
    let palette: ColorPalette
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        ForEach(0..<palette.colors.count, id: \.self) { index in
                            VStack(spacing: 15) {
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(palette.colors[index])
                                    .frame(height: 100)
                                    .shadow(radius: 5)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Color \(index + 1)")
                                        .font(.headline)
                                    Text(palette.hexCodes[index])
                                        .font(.subheadline)
                                    Text(palette.rgbValues[index])
                                        .font(.subheadline)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Palette Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let onImageSelected: (UIImage?) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                        self.parent.onImageSelected(image as? UIImage)
                    }
                }
            }
        }
    }
}

extension Color {
    var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
    
    var hexCode: String {
        let components = self.components
        return String(format: "#%02X%02X%02X",
                     Int(components.red * 255),
                     Int(components.green * 255),
                     Int(components.blue * 255))
    }
    
    var rgbValue: String {
        let components = self.components
        return String(format: "RGB(%d, %d, %d)",
                     Int(components.red * 255),
                     Int(components.green * 255),
                     Int(components.blue * 255))
    }
    
    var hslValue: String {
        let components = self.components
        let r = components.red
        let g = components.green
        let b = components.blue
        
        let max = Swift.max(r, g, b)
        let min = Swift.min(r, g, b)
        let delta = max - min
        
        var h: CGFloat = 0
        var s: CGFloat = 0
        let l = (max + min) / 2
        
        if delta != 0 {
            s = l > 0.5 ? delta / (2 - max - min) : delta / (max + min)
            
            if max == r {
                h = (g - b) / delta + (g < b ? 6 : 0)
            } else if max == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            
            h *= 60
        }
        
        return String(format: "HSL(%.0f, %.0f%%, %.0f%%)",
                     h,
                     s * 100,
                     l * 100)
    }
}

#Preview {
    ContentView()
}
