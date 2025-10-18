/*
 Copyright © 2020 Apple Inc.
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

import SwiftUI

public struct VisualEffectBlur<Content: View>: View {
    #if os(tvOS) || os(iOS)
    var blurStyle: UIBlurEffect.Style

    var content: Content
    var cornerRadius: CGFloat = 6.0

    public init(blurStyle: UIBlurEffect.Style = .light, @ViewBuilder content: () -> Content) {
        self.blurStyle = blurStyle
        self.content = content()
    }
    
    public var body: some View {
        Representable(blurStyle: blurStyle, content: EmptyView())
            .overlay{ content }
            .cornerRadius(cornerRadius)
            .accessibility(hidden: Content.self == EmptyView.self)
    }
    
    #elseif os(macOS)
    var content: Content
    var cornerRadius: CGFloat = 6.0

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        Rectangle()
            .fill(.regularMaterial).cornerRadius(cornerRadius)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .center) {
                content
            }
    }
    #endif
}

// MARK: - Representable
extension VisualEffectBlur {
    #if os(tvOS)  || os(iOS)
    struct Representable<Content: View>: UIViewRepresentable {
        var blurStyle: UIBlurEffect.Style
        var vibrancyEffect: UIVibrancyEffect?
        var content: Content

        func makeUIView(context: Context) -> UIVisualEffectView {
            context.coordinator.blurView
        }

        func updateUIView(_ view: UIVisualEffectView, context: Context) {
            context.coordinator.update(content: content, blurStyle: blurStyle)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(content: content)
        }
    }
    #elseif os(macOS)
    struct Representable<Content: View>: NSViewRepresentable {
        var content: Content
        
        func makeNSView(context: Context) -> NSVisualEffectView {
            return context.coordinator.visualEffectView
        }

        func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
            context.coordinator.update(content: content)
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(content: content)
        }
    }
    #endif
}

#if os(tvOS)  || os(iOS)
// MARK: - Coordinator
extension VisualEffectBlur.Representable {
    class Coordinator {
        let blurView = UIVisualEffectView()
        let hostingController: UIHostingController<Content>

        init(content: Content) {
            hostingController = UIHostingController(rootView: content)
            hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            hostingController.view.backgroundColor = nil
            
            blurView.contentView.addSubview(hostingController.view)
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }

        func update(content: Content, blurStyle: UIBlurEffect.Style) {
            hostingController.rootView = content

            let blurEffect = UIBlurEffect(style: blurStyle)
            blurView.effect = blurEffect

            hostingController.view.setNeedsDisplay()
        }
    }
}

// MARK: - Content-less Initializer
public extension VisualEffectBlur where Content == EmptyView {
    init(blurStyle: UIBlurEffect.Style = .regular) {
        self.init(blurStyle: blurStyle) {
            EmptyView()
        }
    }
}
#elseif os(macOS)
// MARK: - Coordinator
extension VisualEffectBlur.Representable {
    class Coordinator {
        let material: NSVisualEffectView.Material = .contentBackground
        let blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
        let hostingController: NSHostingController<Content>
        let visualEffectView: NSVisualEffectView

        init(content: Content) {
            hostingController = NSHostingController(rootView: content)
            hostingController.view.autoresizingMask = [.width, .height]
            
            visualEffectView = NSVisualEffectView()
            visualEffectView.material = material
            visualEffectView.blendingMode = blendingMode
            visualEffectView.state = .active
            visualEffectView.addSubview(hostingController.view)
            visualEffectView.autoresizingMask = [.width, .height]
        }

        func update(content: Content) {
            hostingController.rootView = content
        }
    }
}

// MARK: - Content-less Initializer
public extension VisualEffectBlur where Content == EmptyView {
    init() {
        self.init() {
            EmptyView()
        }
    }
}
#endif
