//
//  ProfileView.swift
//  Avatar · stats · appearance segmented control · settings rows · sign out.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @Query(filter: #Predicate<ContentItem> { !$0.isArchived }) private var items: [ContentItem]
    @Query private var collections: [ContentCollection]
    @Query private var tags: [Tag]

    private var session: AuthSession? { container.authService.currentSession }

    var body: some View {
        @Bindable var appState = appState
        ScrollView {
            VStack(spacing: 0) {
                Circle()
                    .fill(LinearGradient(colors: [LNColor.accent, LNColor.accent.opacity(0.65)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 78, height: 78)
                    .overlay {
                        Text(initials)
                            .font(.system(size: 27, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 20)
                Text(session?.userName ?? "Maya Chen")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(LNColor.primaryText)
                    .padding(.top, 12)
                Text(session?.email ?? "maya.chen@icloud.com")
                    .font(.system(size: 13))
                    .foregroundStyle(LNColor.secondaryText)
                    .padding(.top, 2)

                StatsCard(stats: [
                    (String(localized: "stat.saved", defaultValue: "Saved"), items.count),
                    (String(localized: "stat.collections", defaultValue: "Collections"), collections.count),
                    (String(localized: "stat.favorites", defaultValue: "Favorites"), items.filter(\.isFavorite).count),
                    (String(localized: "stat.tags", defaultValue: "Tags"), tags.count)
                ])
                .padding(.horizontal, LNSpacing.gutter)
                .padding(.top, 20)

                LNGroupCard {
                    HStack {
                        Text(String(localized: "profile.appearance", defaultValue: "Appearance"))
                            .font(.system(size: 15))
                            .foregroundStyle(LNColor.primaryText)
                        Spacer()
                        Picker(String(localized: "profile.appearance", defaultValue: "Appearance"),
                               selection: $appState.themeMode) {
                            ForEach(ThemeMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 190)
                    }
                    .padding(.horizontal, 15)
                    .frame(minHeight: 52)
                    LNRowSeparator()
                    settingsRow(String(localized: "profile.notifications", defaultValue: "Notifications"))
                    LNRowSeparator()
                    HStack {
                        Text(String(localized: "profile.icloud", defaultValue: "iCloud Sync"))
                            .font(.system(size: 15))
                            .foregroundStyle(LNColor.primaryText)
                        Spacer()
                        Text(String(localized: "profile.upToDate", defaultValue: "Up to date"))
                            .font(.system(size: 13.5))
                            .foregroundStyle(LNColor.secondaryText)
                    }
                    .padding(.horizontal, 15)
                    .frame(minHeight: 52)
                    LNRowSeparator()
                    settingsRow(String(localized: "profile.settings", defaultValue: "Settings"))
                }
                .padding(.horizontal, LNSpacing.gutter)
                .padding(.top, 18)

                LNGroupCard {
                    Button {
                        container.authService.signOut()
                        Task { await container.syncService.stop() }
                        // Local storage is shared by whoever's signed in on this
                        // device — clear it so the next account never sees this
                        // one's library.
                        container.contentRepository.clearLocal()
                        container.collectionRepository.clearLocal()
                        container.tagRepository.clearLocal()
                        router.resetToHome()
                        appState.phase = .auth
                    } label: {
                        Text(String(localized: "profile.signOut", defaultValue: "Sign Out"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(LNColor.destructive)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, LNSpacing.gutter)
                .padding(.top, 14)

                Text(String(localized: "profile.version", defaultValue: "LinkNest 1.0"))
                    .font(.system(size: 12))
                    .foregroundStyle(LNColor.tertiaryText)
                    .padding(.top, 18)
            }
            .padding(.bottom, 120)
        }
        .background(LNColor.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var initials: String {
        let parts = (session?.userName ?? "Maya Chen").split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    private func settingsRow(_ title: String) -> some View {
        Button {
            appState.showToast(String(localized: "toast.nextRound", defaultValue: "Coming in the next round"))
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(LNColor.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LNColor.tertiaryText)
            }
            .padding(.horizontal, 15)
            .frame(minHeight: 52)
        }
        .buttonStyle(.plain)
    }
}
