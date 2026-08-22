//
//  PlayerLayerView.swift
//  UIViewRepresentable hosting a real AVPlayerLayer (not VideoPlayer/
//  AVPlayerViewController) so the custom LinkNest overlay is the only
//  chrome, while still wiring up a genuine AVPictureInPictureController.
//  Pure display surface — tap/double-tap handling lives in the SwiftUI
//  `VideoTapGestureLayer` overlaid on top (see VideoPlayerView), the same
//  layer used for the YouTube surface, so both sources share one gesture
//  implementation instead of a UIKit one here and a SwiftUI one there.
//

import SwiftUI
import AVKit

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    var onPiPControllerReady: (AVPictureInPictureController) -> Void

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect

        if AVPictureInPictureController.isPictureInPictureSupported() {
            let controller = AVPictureInPictureController(playerLayer: view.playerLayer)
            controller?.canStartPictureInPictureAutomaticallyFromInline = true
            if let controller { onPiPControllerReady(controller) }
            context.coordinator.pipController = controller
        }
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var pipController: AVPictureInPictureController?
    }

    final class PlayerContainerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
