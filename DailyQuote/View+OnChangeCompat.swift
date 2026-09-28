import SwiftUI

extension View {
    /// `onChange(of:perform:)` is deprecated in iOS 17, but the app still
    /// supports iOS 16. Uses the iOS 17 API when available, and the old one
    /// otherwise, without deprecation warnings. The action gets the new value.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            onChange(of: value) { _, newValue in action(newValue) }
        } else {
            onChange(of: value, perform: action)
        }
    }
}
