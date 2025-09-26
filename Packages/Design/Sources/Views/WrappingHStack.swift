/// Taken from https://liudasbar.medium.com/swiftui-hstack-but-with-wrapping-4b40ba8b7819

import SwiftUI

public struct WrappingCollectionView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    private let data: Data
    private let spacing: CGFloat
    private let content: (Data.Element) -> Content
    @State private var totalHeight: CGFloat = .zero
    
    public init(
        data: Data,
        spacing: CGFloat = 8,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.spacing = spacing
        self.content = content
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geometry in
                generateContent(in: geometry)
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
                    })
            }
        }
        .onPreferenceChange(HeightPreferenceKey.self) { height in
            totalHeight = height
        }
        .frame(height: totalHeight)
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(data) { item in
                content(item)
                    .alignmentGuide(
                        .leading,
                        computeValue: { dimension in
                            if abs(width - dimension.width) > geometry.size.width {
                                width = 0
                                height -= dimension.height + spacing
                            }
                            
                            let result = width
                            if item.id == data.last?.id {
                                width = 0
                            } else {
                                width -= dimension.width + spacing
                            }
                            return result
                        }
                    )
                    .alignmentGuide(
                        .top,
                        computeValue: { _ in
                            let result = height
                            if item.id == data.last?.id {
                                height = 0
                            }
                            return result
                        }
                    )
            }
        }
    }
}

struct HeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}
