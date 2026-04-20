import SwiftUI
import Combine

// MARK: - compatOnChange

// The two-parameter onChange(of:) { oldValue, newValue in } form requires iOS 17.
// The single-parameter form requires iOS 14.
// This modifier works on iOS 13+ using onReceive(Just(_:)).

extension View {
    func compatOnChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        modifier(CompatOnChangeModifier(value: value, action: action))
    }
}

private struct CompatOnChangeModifier<V: Equatable>: ViewModifier {
    let value: V
    let action: (V) -> Void
    @State private var previous: V

    init(value: V, action: @escaping (V) -> Void) {
        self.value = value
        self.action = action
        _previous = State(initialValue: value)
    }

    func body(content: Content) -> some View {
        content.onReceive(Just(value)) { current in
            guard current != previous else { return }
            previous = current
            action(current)
        }
    }
}

// MARK: - ActivityIndicatorView

// ProgressView requires iOS 14. This view wraps UIActivityIndicatorView for iOS 13.

struct ActivityIndicatorView: UIViewRepresentable {
    var color: UIColor = .white
    var style: UIActivityIndicatorView.Style = .medium

    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView(style: style)
        view.color = color
        view.hidesWhenStopped = false
        view.startAnimating()
        return view
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        uiView.color = color
    }
}
