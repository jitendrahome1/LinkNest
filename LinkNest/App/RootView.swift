//
//  RootView.swift
//  Launch-phase switch: Splash → Onboarding → Auth → Main.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    var body: some View {
        ZStack {
            LNColor.background.ignoresSafeArea()
            switch appState.phase {
            case .splash:
                SplashView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingView()
                    .transition(.opacity)
            case .auth:
                AuthView()
                    .transition(.opacity)
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.phase)
        .modifier(ToastOverlay())
        .onOpenURL { url in
            DeepLinkHandler(router: router).handle(url)
        }
    }
}

#Preview {
    let container = AppContainer.preview()
    return RootView()
        .environment(container)
        .environment(container.appState)
        .environment(container.router)
        .modelContainer(container.modelContainer)
}
