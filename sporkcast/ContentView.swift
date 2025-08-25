//
//  ContentView.swift
//  sporkcast
//
//  Created by Tom Knighton on 22/08/2025.
//

import SwiftUI

private struct TitleBottomYKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ContentView: View {
    @State private var offset: CGFloat = 0
    @State private var showNavTitle = false
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    ZStack(alignment: .bottom) {
                        image()
                            .frame(height: 350)
                            .clipped()
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.00),
                                .init(color: .black, location: 0.99),
                                .init(color: .black, location: 1.00)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .blendMode(.destinationOut)
                        .allowsHitTesting(false)
                        .frame(height: 200)
                    }
                    .ignoresSafeArea()
                    .compositingGroup()
                    .stretchy()
                    
                    VStack(alignment: .leading) {
                        Text("Bon Appetit")
                            .font(.footnote.weight(.heavy))
                            .opacity(0.6)
                        Text("Creamy Mustard Chicken")
                            .font(.title.weight(.bold))
                            .background(
                                GeometryReader { proxy in
                                    Color.clear
                                        .preference(
                                            key: TitleBottomYKey.self,
                                            value: proxy.frame(in: .named("scroll")).maxY
                                        )
                                }
                            )
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, -16)
                    
                    VStack {
                        HStack {
                            VStack {
                                Text("XXX")
                                Text("xxx")
                            }
                            .glassEffect()
                            
                            VStack {
                                Text("XXX")
                                Text("xxx")
                            }
                            .glassEffect()
                            
                            VStack {
                                Text("XXX")
                                Text("xxx")
                            }
                            .glassEffect()
                        }
                        Text(String(describing: offset))
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                        Text("Hi")
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: CGFloat.self, of: { geo in
                return geo.contentOffset.y + geo.contentInsets.top
            }, action: { new, old in
                offset = new
            })
        }
        .ignoresSafeArea()
        .background(
            image()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(2)
                .blur(radius: scheme == .dark ? 100 : 64)
                .ignoresSafeArea()
        )
        .colorScheme(.dark)
        .onPreferenceChange(TitleBottomYKey.self) { bottom in
            let collapsed = bottom < 0
            if collapsed != showNavTitle {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNavTitle = collapsed
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {}) {
                    Image(systemName: "xmark")
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Creamy Mustard Chicken")
                    .font(.headline)
                    .opacity(showNavTitle ? 1 : 0)
                    .accessibilityHidden(!showNavTitle)
                    .animation(.easeInOut(duration: 0.2), value: showNavTitle)
            }
        }
    }
    
    @ViewBuilder
    private func image() -> some View {
        AsyncImage(url: URL(string: "https://images.immediate.co.uk/production/volatile/sites/30/2020/08/swedish-meatball-burgers-e01dcfe.jpg?resize=440,400")) { img in
            img
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            EmptyView()
        }
        .frame(height: 350)
        .clipped()
        
    }
}

#Preview {
    NavigationStack {
        ContentView()
        //            .navigationTitle("Creamy")
            .toolbarTitleDisplayMode(.inline)
    }
}


extension View {
    func stretchy() -> some View {
        visualEffect { effect, geometry in
            let currentHeight = geometry.size.height
            let scrollOffset = geometry.frame(in: .scrollView).minY
            let positiveOffset = max(0, scrollOffset)
            
            let newHeight = currentHeight + positiveOffset
            let scaleFactor = newHeight / currentHeight
            
            return effect.scaleEffect(
                x: scaleFactor, y: scaleFactor,
                anchor: .bottom
            )
        }
    }
}
