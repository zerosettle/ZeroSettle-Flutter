import Flutter
import UIKit
import ZeroSettleKit
import SwiftUI

/// UIView subclass that fires `onLayout` after every `layoutSubviews()` pass
/// so the container can read the hosted SwiftUI view's intrinsic size and
/// push it back to Flutter. SwiftUI's hosting view doesn't expose a
/// well-defined "intrinsic content size changed" hook, so we sample on
/// every layout cycle and dedupe in the Swift container.
private final class _LayoutObservingView: UIView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

class MigrationTipViewFlutterContainer: NSObject, FlutterPlatformView {
    private let containerView: _LayoutObservingView
    private var hostingController: UIHostingController<MigrationTipView>?

    /// Per-view MethodChannel that this container pushes size updates to.
    /// The Dart `MigrationTipView` widget subscribes to it on
    /// `onPlatformViewCreated(viewId)` and rebuilds with the reported height.
    private let methodChannel: FlutterMethodChannel

    /// Last height we sent to Flutter. Used to suppress duplicate calls when
    /// `layoutSubviews` fires repeatedly with the same intrinsic size.
    private var lastReportedHeight: CGFloat = -1

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        arguments args: Any?
    ) {
        let channel = FlutterMethodChannel(
            name: "zerosettle/migrate_tip_view_\(viewId)",
            binaryMessenger: messenger
        )
        self.methodChannel = channel

        let containerView = _LayoutObservingView(frame: frame)
        self.containerView = containerView
        super.init()

        // Parse creation arguments
        var backgroundColor = Color.black
        var userId = ""

        if let args = args as? [String: Any] {
            // Convert Flutter Color (ARGB int32) to SwiftUI Color
            if let colorInt = args["backgroundColor"] as? Int {
                let a = Double((colorInt >> 24) & 0xFF) / 255.0
                let r = Double((colorInt >> 16) & 0xFF) / 255.0
                let g = Double((colorInt >> 8) & 0xFF) / 255.0
                let b = Double(colorInt & 0xFF) / 255.0
                backgroundColor = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
            }
            userId = args["userId"] as? String ?? ""
        }

        // Create SwiftUI view
        let swiftUIView = MigrationTipView(
            userId: userId,
            backgroundColor: backgroundColor
        )

        // Wrap in UIHostingController
        let hostingController = UIHostingController(rootView: swiftUIView)
        self.hostingController = hostingController

        // Configure hosting controller
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        // Add to container
        containerView.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        // Wire up dynamic-sizing callback. Every time the container lays out
        // (which fires after the SwiftUI body re-renders to a new size), we
        // ask the hosted view for its compressed natural height and ship it
        // back to Flutter so the SizedBox stays in sync.
        containerView.onLayout = { [weak self] in
            self?.reportIntrinsicHeight()
        }

        // Attach to parent view controller
        attachHostingControllerIfPossible()
    }

    func view() -> UIView {
        return containerView
    }

    /// Compute the SwiftUI view's natural (compressed) height for the current
    /// width and forward it to Flutter. Width is fixed by Flutter's parent
    /// layout; we let height grow to whatever SwiftUI wants.
    private func reportIntrinsicHeight() {
        guard let hc = hostingController else { return }

        // `containerView.bounds.width` is what Flutter allotted us. Asking
        // SwiftUI for its compressed size at that width gives the true height
        // of the rendered tip — independent of whatever height Flutter
        // currently has the SizedBox at, which prevents feedback loops.
        let width = containerView.bounds.width
        guard width > 0 else { return }

        let fittingSize = hc.view.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingExpandedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let height = ceil(fittingSize.height)

        // Suppress no-op updates. SwiftUI's hosting view triggers
        // layoutSubviews more often than the body actually changes.
        if abs(height - lastReportedHeight) < 0.5 { return }
        lastReportedHeight = height

        methodChannel.invokeMethod("setSize", arguments: ["height": Double(height)])
    }

    private func attachHostingControllerIfPossible() {
        guard let hc = hostingController else { return }

        // Find parent view controller via responder chain
        var responder: UIResponder? = containerView
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                if hc.parent !== viewController {
                    viewController.addChild(hc)
                    hc.didMove(toParent: viewController)
                }
                return
            }
            responder = nextResponder
        }
    }
}
