import SwiftUI

struct ThemePickerView: View {
    @Binding var selectedIndex: Int

    @Environment(\.dismiss) private var dismiss

    // MARK: - Data
    @State private var customThemes: [ThemeCatalog.Item] = ThemeCatalog.customs

    // MARK: - Filter
    /// Local filter that can target either a built-in category or the customs-only tab.
    private enum Filter: Equatable {
        case builtin(ThemeCatalog.Category)
        case creations
    }
    @State private var filter: Filter = .builtin(.all)

    // Built-ins: wider tiles
    private let columnsBuiltins: [GridItem] = [
        GridItem(.adaptive(minimum: 120, maximum: 220), spacing: 14)
    ]
    // Customs: you set these—kept from your file
    private let columnsCustoms: [GridItem] = [
        GridItem(.adaptive(minimum: 110, maximum: 180), spacing: 24)
    ]

    private var filteredBuiltins: [ThemeCatalog.Item] {
        switch filter {
        case .builtin(let cat):
            return ThemeCatalog.items.filter { cat == .all ? true : $0.category == cat }
        case .creations:
            return [] // not used in this mode
        }
    }

    /// Linear list used to map an Item back to a single Int index
    private var allItemsLinear: [ThemeCatalog.Item] { ThemeCatalog.items + customThemes }

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // 👉 Always-grey background for the sheet
                Color(.systemGray6).ignoresSafeArea()

                VStack(spacing: 10) {
                    header

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {

                            // ===== Built-ins mode =====
                            if case .builtin = filter {
                                LazyVGrid(columns: columnsBuiltins, spacing: 14) {
                                    ForEach(filteredBuiltins) { item in
                                        ThemeCard(item: item) {
                                            if let idx = allItemsLinear.firstIndex(of: item) {
                                                selectedIndex = idx
                                                UserDefaults.standard.set(selectedIndex, forKey: "selectedThemeIndex")
                                                dismiss()
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)

                                // Optional section with customs below (like your existing layout)
                                if !customThemes.isEmpty {
                                    Text("Your creations")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.primary)          // 👈 adaptive text
                                        .padding(.top, 6)
                                        .padding(.horizontal)

                                    LazyVGrid(columns: columnsCustoms, spacing: 12) {
                                        ForEach(customThemes) { item in
                                            ThemeCard(item: item) {
                                                if let idx = allItemsLinear.firstIndex(of: item) {
                                                    selectedIndex = idx
                                                    UserDefaults.standard.set(selectedIndex, forKey: "selectedThemeIndex")
                                                    dismiss()
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.leading, 12)
                                }
                            }

                            // ===== Creations-only mode =====
                            if case .creations = filter {
                                Text("Your creations")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.primary)              // 👈 adaptive text
                                    .padding(.horizontal)
                                    .padding(.top, 6)

                                if customThemes.isEmpty {
                                    Text("No custom themes yet. Tap **Create** to add one!")
                                        .font(.headline)
                                        .foregroundColor(.secondary)        // 👈 softer adaptive text
                                        .padding(.horizontal)
                                } else {
                                    LazyVGrid(columns: columnsCustoms, spacing: 12) {
                                        ForEach(customThemes) { item in
                                            ThemeCard(item: item) {
                                                if let idx = allItemsLinear.firstIndex(of: item) {
                                                    selectedIndex = idx
                                                    UserDefaults.standard.set(selectedIndex, forKey: "selectedThemeIndex")
                                                    dismiss()
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.leading, 12)
                                }
                            }
                        }
                        .padding(.top, 14)
                        .padding(.bottom, 24)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCreateFullScreen) {
                CreateThemeFullScreen { image, name in
                    if let path = ThemeCatalog.savePNG(image: image, filename: name) {
                        ThemeCatalog.appendCustomPath(path)
                        ThemeCatalog.reloadCustoms()
                        customThemes = ThemeCatalog.customs

                        let newIndex = ThemeCatalog.items.count + (customThemes.count - 1)
                        selectedIndex = ThemeCatalog.clampedIndex(from: newIndex)
                        UserDefaults.standard.set(selectedIndex, forKey: "selectedThemeIndex")

                        // If user is on Creations tab, keep them there and show the new item immediately.
                        filter = .creations
                    }
                }
            }
            .interactiveDismissDisabled(true)
            .onReceive(NotificationCenter.default.publisher(for: .customThemeCatalogChanged)) { _ in
                ThemeCatalog.reloadCustoms()
                customThemes = ThemeCatalog.customs
                selectedIndex = ThemeCatalog.clampedIndex(from: selectedIndex)
            }
            .onAppear {
                ThemeCatalog.reloadCustoms()
                customThemes = ThemeCatalog.customs
                selectedIndex = ThemeCatalog.clampedIndex(from: selectedIndex)
            }
        }
    }

    // MARK: - Header & chips
    @State private var showCreateFullScreen = false
    private var header: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Themes")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)                 // 👈 adaptive

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary.opacity(0.9)) // 👈 adaptive
                        .padding(8)
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal)
            .padding(.top, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button { showCreateFullScreen = true } label: {
                        Label("Create", systemImage: "plus")
                            .font(.headline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray5))            // 👈 grey chip
                            )
                            .overlay(
                                Capsule().stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .foregroundColor(.primary)                   // 👈 adaptive text
                    }

                    // Built-in categories
                    ForEach(ThemeCatalog.Category.allCases, id: \.self) { cat in
                        Chip(
                            title: cat.rawValue,
                            isSelected: filter == .builtin(cat)
                        ) {
                            filter = .builtin(cat)
                        }
                    }

                    // NEW chip – Your creations
                    Chip(
                        title: "Your creations",
                        isSelected: filter == .creations
                    ) {
                        filter = .creations
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Small chip view to avoid repeating style
private struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        isSelected
                        ? Color.accentColor.opacity(0.18)          // selected chip
                        : Color(.systemGray5)                      // unselected chip
                    )
                )
                .overlay(
                    Capsule().stroke(Color(.systemGray4), lineWidth: 1)
                )
                .foregroundColor(
                    isSelected ? Color.accentColor : Color.primary // 👈 adaptive text
                )
        }
    }
}

// Shared card; height is derived from width via aspect ratio
private struct ThemeCard: View {
    let item: ThemeCatalog.Item
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                ThemeCatalog.image(for: item)
                    .resizable()
                    .scaledToFill()
                    .aspectRatio(2/3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(item.displayName)
                    .font(.headline.weight(.semibold))
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                    .foregroundColor(.white)                     // keep white over the card image
                    .padding(10)
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipped()
    }
}
