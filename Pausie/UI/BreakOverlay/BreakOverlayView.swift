import AppKit
import SwiftUI

/// Content of one break-layer panel: the dim layer, and on the main display the card for the current state
/// plus the skip confirmation when it is open.
struct BreakOverlayView: View {
    let session: SessionController
    let settings: SettingsStore
    let showsCard: Bool
    /// The break-over sound chip opens Settings.
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack {
            BackdropBlur()
                .opacity(OpacityToken.breakBlur)
            Color(.overlayDim)
                .opacity(OpacityToken.breakDim)

            if showsCard {
                card
                if session.isSkipConfirmationPresented {
                    Color(.overlayDim)
                        .opacity(OpacityToken.skipScrim)
                    SkipConfirmView(session: session)
                }
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var card: some View {
        switch session.state {
        case .breakNoteRequired:
            BreakCardView(session: session, mode: .noteRequired)
        case .onBreak:
            BreakCardView(session: session, mode: .running)
        case .breakOver:
            BreakOverView(session: session, settings: settings, onChangeSound: onOpenSettings)
        default:
            EmptyView()
        }
    }
}

/// A light backdrop blur behind the dim layer.
private struct BackdropBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .fullScreenUI
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
