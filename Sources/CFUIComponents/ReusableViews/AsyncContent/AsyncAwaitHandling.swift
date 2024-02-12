//
//  AsyncAwaitHandling.swift
//  CFCompanent


import SwiftUI
import Foundation

@frozen public enum AsyncResult<Success> {
    case empty
    case inProgress
    case success(Success)
    case failure(Error, haveRetry: Bool = true)
    
    public var value: Success? {
        switch self {
        case .success(let success): return success
        default: return nil
        }
    }
    
    public var error: Error? {
        switch self {
        case .failure(let error, _): return error
        default: return nil
        }
    }
}

public protocol AsyncViewModel: ObservableObject {
    associatedtype Output
    var result: AsyncResult<Output> { get set }
    func asyncOperation() async throws -> Output
    func load() async
    func loadIfNeeded() async
}

public extension AsyncViewModel {
    @MainActor
    func load() async {
        if case .inProgress = self.result { return }
        self.result = .inProgress
        
        do {
            self.result = .success(try await self.asyncOperation())
        } catch {
            self.result = .failure(error)
        }
    }
    
    func loadWithoutProgress() async {
        if case .inProgress = self.result { return }
    
        do {
            self.result = .success(try await self.asyncOperation())
        } catch {
            self.result = .failure(error)
        }
    }
    
    @MainActor
    func loadIfNeeded() async {
        switch self.result {
        case .empty, .failure:
            await self.load()
        case .inProgress, .success:
            break
        }
    }
}

open class AsyncViewModelDefault<Success>: AsyncViewModel {
    @MainActor @Published public var result = AsyncResult<Success>.empty
    
    public typealias AsyncOperation = () async throws -> Success
    
    private var asyncOperationBlock: AsyncOperation = {
        fatalError("Override asyncOperation or pass a asyncOperationBlock to use async model")
    }
    
    public init(asyncOperation: AsyncOperation? = nil) {
        if let asyncOperation = asyncOperation {
            self.asyncOperationBlock = asyncOperation
        }
    }
    
    open func asyncOperation() async throws -> Success {
        try await self.asyncOperationBlock()
    }
}

public struct AsyncView<Source: AsyncViewModel, Content: View>: View {
    public typealias EmptyBlock = () -> AnyView
    public typealias LoadingBlock = () -> AnyView
    public typealias ContentBlock = (_ value: Source.Output) -> Content
    public typealias ErrorBlock = (Error, Source, Bool) -> AnyView
    
    @ObservedObject var source: Source
    var hideLoading: Bool
    var empty: EmptyBlock
    var loading: LoadingBlock
    let content: ContentBlock
    var error: ErrorBlock
    
    public var body: some View {
        switch source.result {
        case .empty: self.empty().onAppear { Task { await source.loadIfNeeded() } }
        case .inProgress:
            if !hideLoading {
                self.loading()
            }
        case .success(let value): self.content(value)
        case .failure(let error, let haveRetry): self.error(error, source, haveRetry)
        }
    }
}

public extension AsyncView {
    init(source: Source, isHideLoading: Bool = false, @ViewBuilder content: @escaping (_ value: Source.Output) -> Content) {
        self.source = source
        self.empty = { Text("").asAnyView() }
        self.loading = { ActivityIndicator(style: .large, color: .gray).asAnyView() }
        self.content = content
        self.error = { error, source, haveRetry in AsyncErrorView(error: error, source: source, haveRetry: haveRetry).asAnyView() }
        self.hideLoading = isHideLoading
    }
    
    init<P>(operation: @escaping AsyncViewModelDefault<Source.Output>.AsyncOperation,
            @ViewBuilder content: @escaping (_ item: Source.Output) -> Content) where Source == AsyncViewModelDefault<P> {
        self.init(source: AsyncViewModelDefault(asyncOperation: operation), content: content)
    }
    
    func setEmptyView(_ block: @escaping EmptyBlock) -> Self {
        then { $0.empty = block }
    }
    
    func setLoadingView(_ block: @escaping LoadingBlock) -> Self {
        then { $0.loading = block }
    }
    
    func setErrorView(_ block: @escaping ErrorBlock) -> Self {
        then { $0.error = block }
    }

}

public struct AsyncErrorView<Source: AsyncViewModel>: View {
    let error: Error
    let source: Source
    let haveRetry: Bool
    
    public init(error: Error, source: Source, haveRetry: Bool = true) {
        self.error = error
        self.source = source
        self.haveRetry = haveRetry
    }
    
    public var body: some View {
        VStack(spacing: 30) {
            Text(error.localizedDescription)
            if haveRetry {
                CFButton(action: { Task { await source.load() } }) {
                    HStack(spacing: 12) {
                        Text("try_again".localized)
                        Image(systemName: "arrow.clockwise")
                    }
                }.height(40).hPadding(20).fixedSize().defaultButton().setCornerRadius()
            }
        }
    }
}
