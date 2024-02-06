//
//  SwiftUIView.swift
//  
//
//  Created by Le Quang Tuan Cuong(CuongLQT) on 06/02/2024.
//

import SwiftUI

/// Creates a list that displays a custom Content.
public struct CFListView<Content, Divider: View, Model: Identifiable>: View where Content: View {
    
    private var items: [Model]
    private var contentView: (Int, Model) -> Content
    private var dividerView: Divider?
    private var itemSpacing: CGFloat
    
    /// Creates a list that displays a custom Content.
    /// - Parameters:
    ///   - items: List of objects to display
    ///   - itemView: Custom view of row
    ///   - dividerView: Divider view of between rows
    ///   - itemSpacing: Spacing between cells
    public init(items: [Model],
                itemSpacing: CGFloat = 0,
                @ViewBuilder contentView: @escaping (Int, Model) -> Content,
                dividerView: (() -> Divider)? = nil) {
        self.items = items
        self.contentView = contentView
        self.dividerView = dividerView?()
        self.itemSpacing = itemSpacing
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            ForEach(items.enumeratedArray(), id: \.offset) { index, item in
                contentView(index, item)
                if index < (items.count - 1), dividerView != nil {
                    dividerView
                }
            }
        }
    }
}

// Support optional for divider
public extension CFListView where Divider == EmptyView {
    init(items: [Model],
         itemSpacing: CGFloat = 0,
         @ViewBuilder contentView: @escaping (Int, Model) -> Content) {
        self.items = items
        self.contentView = contentView
        self.itemSpacing = itemSpacing
    }
}
