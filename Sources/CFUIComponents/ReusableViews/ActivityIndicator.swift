//
//  ActivityIndicator.swift
//  UICompanent

#if canImport(SwiftUI) && os(iOS)
import SwiftUI
import Combine

extension Notification.Name {
    static let alertDismiss = Notification.Name("alertDismiss")
}

struct ActivityIndicatorView<BackgroundContent, Content>: View where Content: View, BackgroundContent: View {
    @State private var isPresented: Bool = false
    
    var contentView: Content
    var backgroundView: BackgroundContent
    var animation: Animation
    
    var body: some View {
        ZStack {
            backgroundView
                .animate { self.isPresented = true }
            contentView
                .padding(30)
                .backgroundColor(.white)
                .cornerRadius(10)
                .scale(isPresented ? 1 : 0)
                .animation(animation)
        }
        .edgesIgnoringSafeArea(.all)
        .onReceive(NotificationCenter.default.publisher(for: .alertDismiss)) { _ in
            withAnimation { self.isPresented = false }
        }
    }
}

public struct ActivityIndicator: UIViewRepresentable {
    let style: UIActivityIndicatorView.Style
    let color: UIColor
    
    public init(style: UIActivityIndicatorView.Style = .large, color: UIColor = .white) {
        self.style = style
        self.color = color
    }
    
    public func makeUIView(context: Context) -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView()
        indicator.style = style
        indicator.color = color
        return indicator
    }
    
    public func updateUIView(_ uiView: UIActivityIndicatorView,
                             context: Context) {
        uiView.startAnimating()
    }
}

#endif
