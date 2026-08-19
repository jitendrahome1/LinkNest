//
//  PlayerLayerView.swift
//  UIViewRepresentable hosting a real AVPlayerLayer (not VideoPlayer/
//  AVPlayerViewController) so the custom LinkNest overlay is the only
//  chrome, while still wiring up a genuine AVPictureInPictureController.
//

import SwiftUI
import AVKit

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    var onTap: () -> Void
    var onPiPControllerReady: (AVPictureInPictureController) -> Void

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        view.addGestureRecognizer(tap)

        if AVPictureInPictureController.isPictureInPictureSupported() {
            let controller = AVPictureInPictureController(playerLayer: view.playerLayer)
            controller?.canStartPictureInPictureAutomaticallyFromInline = true
            if let controller { onPiPControllerReady(controller) }
            context.coordinator.pipController = controller
        }
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        context.coordinator.onTap = onTap
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    final class Coordinator {
        var onTap: () -> Void
        var pipController: AVPictureInPictureController?

        init(onTap: @escaping () -> Void) { self.onTap = onTap }

        @objc func handleTap() { onTap() }
    }

    final class PlayerContainerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
