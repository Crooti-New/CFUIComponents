//
//  AsyncContentView.swift
//  CFCompanent

#if canImport(SwiftUI) && os(iOS)
import SwiftUI
import Combine
// MARK: - Loadable
public enum Loadable<T> {
    case idle
    case isLoading(last: T?, cancelBag: AnyCancellable)
    case loaded(T)
    case failed(Error)
    
    public var value: T? {
        switch self {
        case let .loaded(value): return value
        case let .isLoading(last, _): return last
        default: return nil
        }
    }
    
    public var error: Error? {
        switch self {
        case let .failed(error): return error
        default: return nil
        }
    }
}

public extension Loadable {
    mutating func setIsLoading(cancelBag: AnyCancellable) {
        self = .isLoading(last: value, cancelBag: cancelBag)
    }
    
    mutating func cancelLoading() {
        switch self {
        case let .isLoading(last, cancelBag):
            cancelBag.cancel()
            if let last = last {
                self = .loaded(last)
            } else {
                let error = NSError(
                    domain: NSCocoaErrorDomain, code: NSUserCancelledError,
                    userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Canceled by user", comment: "")])
                self = .failed(error)
            }
        default: break
        }
    }
}

// MARK: - LoadableObject
public protocol LoadableObject: ObservableObject {
    associatedtype Output
    var state: Loadable<Output> { get }
    func fetch()
    func cancel()
}

public class PublishedObject<Wrapped: Publisher>: LoadableObject {
    @Published private(set) public var state = Loadable<Wrapped.Output>.idle
    
    private let publisher: Wrapped
    private let defaultPublisher: Wrapped?
    private var cancellableDefault: AnyCancellable?
    private var lastValue: Wrapped.Output?
    
    init(publisher: Wrapped, `default`: Wrapped?) {
        self.publisher = publisher
        self.defaultPublisher = `default`
    }
    
    public func fetch() {
        cancellableDefault = defaultPublisher
            .orEmpty()
            .map { $0 }
            .catch { _ in Empty(completeImmediately: false) }
            .assign(to: \.lastValue, on: self)
        
        let cancellable = publisher
            .delay(for: 0.35, scheduler: RunLoop.main)
            .map(Loadable.loaded)
            .catch { error in
                Just(Loadable.failed(error))
            }
            .assign(to: \.state, on: self)
        state = .isLoading(last: lastValue, cancelBag: cancellable)
    }
    
    public func cancel() {
        state.cancelLoading()
    }
}

public struct LoadableContentView<Source: LoadableObject, Content: View>: View {
    @ObservedObject var source: Source
    let loadingView: (Source) -> AnyView
    let errorView: (Error, Source) -> AnyView
    let content: (Source.Output) -> Content
    
    public init(source: Source,
                loadingView: @escaping (Source) -> AnyView = { _ in Self.defauldLoadingView },
                errorView:  @escaping (Error, Source) -> AnyView = { error, source in Self.defaultErrorView(error, source) },
                @ViewBuilder content: @escaping (Source.Output) -> Content) {
        self.source = source
        self.loadingView = loadingView
        self.errorView = errorView
        self.content = content
    }
    
    public var body: some View {
        switch source.state {
        case .idle:
            Color.clear.onAppear(perform: source.fetch)
        case .isLoading:
            loadingView(self.source)
        case .failed(let error):
            errorView(error, self.source)
        case .loaded(let output):
            content(output)
        }
    }
    
    public static var defauldLoadingView: AnyView {
        ActivityIndicator(style: .large, color: .gray)
            .infinityWidth().infinityHeight()
            .asAnyView()
    }
    
    public static func defaultErrorView<S: LoadableObject>(_ error: Error, _ source: S) -> AnyView {
        VStack {
            VStack(spacing: 20) {
                Text(error.localizedDescription)
                Button { source.fetch() } label: { Text("Retry") }
            }.padding(50)
        }.asAnyView()
    }
}

public extension LoadableContentView {
    init<P: Publisher>(
        sourcePublisher: P,
        defaultSourcePublisher: P? = nil,
        loadingView: @escaping (Source) -> AnyView = { _ in Self.defauldLoadingView },
        errorView:  @escaping (Error, Source) -> AnyView = { error, source in Self.defaultErrorView(error, source) },
        @ViewBuilder content: @escaping (P.Output) -> Content
    ) where Source == PublishedObject<P> {
        self.init(
            source: PublishedObject(publisher: sourcePublisher, default: defaultSourcePublisher),
            loadingView: loadingView,
            errorView: errorView,
            content: content
        )
    }
}

public extension Optional where Wrapped: Combine.Publisher {
    func orEmpty() -> AnyPublisher<Wrapped.Output, Wrapped.Failure> {
        self?.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
    }
}
#endif
