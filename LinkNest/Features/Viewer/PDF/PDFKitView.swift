//
//  PDFKitView.swift
//  UIViewRepresentable wrapping PDFKit's PDFView: continuous vertical
//  scroll, native pinch-to-zoom, a double-tap zoom gesture layered on
//  top, and page-change notifications bridged back to the view model.
//

import SwiftUI
import PDFKit

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int
    var onPageChanged: (Int) -> Void
    var onJumpToPageReady: ((@escaping (Int) -> Void) -> Void)?
    var onHighlightReady: ((@escaping (PDFSelection) -> Void) -> Void)?

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = true
        view.minScaleFactor = view.scaleFactorForSizeToFit * 0.9
        view.maxScaleFactor = 5
        view.backgroundColor = .clear
        view.pageShadowsEnabled = false

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        NotificationCenter.default.addObserver(context.coordinator,
                                                selector: #selector(Coordinator.pageChanged),
                                                name: .PDFViewPageChanged, object: view)

        context.coordinator.pdfView = view
        onJumpToPageReady?({ page in context.coordinator.jump(to: page) })
        onHighlightReady?({ selection in context.coordinator.highlight(selection) })

        if currentPage > 1, let page = document.page(at: currentPage - 1) {
            view.go(to: page)
        }
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        context.coordinator.onPageChanged = onPageChanged
    }

    func makeCoordinator() -> Coordinator { Coordinator(onPageChanged: onPageChanged) }

    final class Coordinator: NSObject {
        weak var pdfView: PDFView?
        var onPageChanged: (Int) -> Void

        init(onPageChanged: @escaping (Int) -> Void) {
            self.onPageChanged = onPageChanged
        }

        @objc func pageChanged() {
            guard let pdfView, let page = pdfView.currentPage,
                  let document = pdfView.document else { return }
            onPageChanged(document.index(for: page) + 1)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView else { return }
            let target: CGFloat = pdfView.scaleFactor > pdfView.scaleFactorForSizeToFit * 1.4
                ? pdfView.scaleFactorForSizeToFit
                : pdfView.scaleFactorForSizeToFit * 2.2
            UIView.animate(withDuration: 0.25) {
                pdfView.scaleFactor = target
            }
        }

        func jump(to page: Int) {
            guard let pdfView, let document = pdfView.document,
                  let target = document.page(at: page - 1) else { return }
            pdfView.go(to: target)
        }

        func highlight(_ selection: PDFSelection) {
            guard let pdfView else { return }
            pdfView.setCurrentSelection(selection, animate: true)
            pdfView.scrollSelectionToVisible(nil)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
