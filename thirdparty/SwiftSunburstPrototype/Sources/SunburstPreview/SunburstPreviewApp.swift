import SunburstCore
import SwiftUI

@main
struct SunburstPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            PreviewRootView()
                .frame(minWidth: 1100, minHeight: 760)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct PreviewRootView: View {
    @State private var root: GenreNode?
    @State private var focusedId: String?
    @State private var selectedNode: GenreNode?
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 320)

            ZStack {
                stageBackground

                if let root {
                    SunburstCanvasView(
                        root: root,
                        focusedId: $focusedId,
                        selectedNode: $selectedNode
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 92)
                    .padding(.bottom, 24)
                    .zIndex(0)

                    VStack(spacing: 10) {
                        topPathBar(root: root)
                        quickJumpBar(root: root)
                        searchBar(root: root)
                        Spacer()
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 18)
                    .zIndex(2)
                } else {
                    ProgressView()
                }
            }
        }
        .task {
            root = loadGenres()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PulseRoots")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.37, green: 0.86, blue: 1.0))
                    .tracking(2.2)
                    .textCase(.uppercase)

                Text(selectedNode?.name ?? "Electronic Music")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            Text(selectedNode?.path ?? "Electronic Music")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.52))

            Divider()
                .overlay(.white.opacity(0.12))

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(selectedNode?.description ?? "Click a segment to focus into that branch. Click the center to move back up. Click empty space to reset.")
                        .font(.system(size: 15, weight: .medium))
                        .lineSpacing(4)
                        .foregroundStyle(.white.opacity(0.84))

                    if let example = selectedNode?.example, !example.isEmpty {
                        Text("Example: \(example)")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(Color(red: 0.81, green: 0.92, blue: 1.0))
                    }

                    if let artists = selectedNode?.keyArtists, !artists.isEmpty {
                        Text("Key artists")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(red: 0.37, green: 0.86, blue: 1.0).opacity(0.78))
                        Text(artists.joined(separator: ", "))
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            Button("Reset") {
                focusedId = nil
                selectedNode = nil
            }
            .keyboardShortcut(.escape)
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.28, green: 0.78, blue: 1.0).opacity(0.24),
                        Color(red: 0.95, green: 0.35, blue: 1.0).opacity(0.18)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
        }
        .padding(24)
        .background(sidebarBackground)
        .foregroundStyle(.white)
    }

    private var stageBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.015, green: 0.025, blue: 0.075),
                    Color(red: 0.055, green: 0.035, blue: 0.13),
                    Color(red: 0.015, green: 0.07, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.17, green: 0.70, blue: 1.0).opacity(0.28),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 520
            )

            RadialGradient(
                colors: [
                    Color(red: 0.96, green: 0.25, blue: 0.95).opacity(0.18),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 30,
                endRadius: 560
            )
        }
        .ignoresSafeArea()
    }

    private var sidebarBackground: some View {
        ZStack {
            Color(red: 0.02, green: 0.035, blue: 0.09).opacity(0.94)
            LinearGradient(
                colors: [
                    .white.opacity(0.075),
                    Color(red: 0.20, green: 0.72, blue: 1.0).opacity(0.035),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(width: 1)
        }
    }

    private func topPathBar(root: GenreNode) -> some View {
        let path = currentPath(root: root)

        return HStack(spacing: 7) {
            ForEach(Array(path.enumerated()), id: \.element.id) { index, node in
                if index > 0 {
                    Text("/")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.36))
                }

                Button {
                    focus(on: node.id == root.id ? nil : node.id, selected: node.id == root.id ? nil : node)
                } label: {
                    Text(node.name)
                        .font(.system(size: index == path.count - 1 ? 14 : 12, weight: index == path.count - 1 ? .bold : .semibold))
                        .foregroundStyle(index == path.count - 1 ? .white : .white.opacity(0.66))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(glassFill, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.15), lineWidth: 1))
    }

    private func quickJumpBar(root: GenreNode) -> some View {
        HStack(spacing: 8) {
            quickJumpButton("Tech House", root: root)
            quickJumpButton("Melodic Dubstep", root: root)
            Spacer()
        }
    }

    private func quickJumpButton(_ name: String, root: GenreNode) -> some View {
        Button {
            jumpToGenre(named: name, root: root)
        } label: {
            Text(name)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.24, green: 0.78, blue: 1.0).opacity(0.22),
                            Color(red: 0.94, green: 0.36, blue: 1.0).opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.26), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func searchBar(root: GenreNode) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Search genres", text: $searchText)
            .textFieldStyle(.plain)
            .focused($searchFieldFocused)
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(glassFill, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(searchFieldFocused ? Color(red: 0.34, green: 0.84, blue: 1.0).opacity(0.72) : .white.opacity(0.14), lineWidth: 1)
            )
            .foregroundStyle(.white)
            .onTapGesture {
                isSearchFocused = true
                searchFieldFocused = true
            }
            .onChange(of: searchFieldFocused) { _, focused in
                isSearchFocused = focused
            }

            let suggestions = searchSuggestions(root: root)
            if isSearchFocused && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.id) { node in
                        Button {
                            jumpToParent(of: node, root: root)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(node.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(node.path)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.58))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)

                        if node.id != suggestions.last?.id {
                            Divider()
                                .overlay(.white.opacity(0.08))
                        }
                    }
                }
                .background(glassFill, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
            }
        }
        .frame(maxWidth: 360, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var glassFill: some ShapeStyle {
        LinearGradient(
            colors: [
                .white.opacity(0.16),
                .white.opacity(0.075)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func currentPath(root: GenreNode) -> [GenreNode] {
        guard let focusedId, let path = root.pathToNode(withId: focusedId) else {
            return [root]
        }

        return path
    }

    private func searchSuggestions(root: GenreNode) -> [GenreNode] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }

        return allNodes(root)
            .filter { $0.id != root.id }
            .filter {
                $0.name.lowercased().contains(query)
                    || $0.path.lowercased().contains(query)
                    || $0.id.lowercased().contains(query)
            }
            .prefix(8)
            .map { $0 }
    }

    private func allNodes(_ node: GenreNode) -> [GenreNode] {
        [node] + node.children.flatMap(allNodes)
    }

    private func jumpToParent(of node: GenreNode, root: GenreNode) {
        let path = root.pathToNode(withId: node.id) ?? [root]
        let parent = path.count > 1 ? path[path.count - 2] : root
        focus(on: parent.id == root.id ? nil : parent.id, selected: node)
        searchText = node.name
        isSearchFocused = false
        searchFieldFocused = false
    }

    private func jumpToGenre(named name: String, root: GenreNode) {
        guard let node = allNodes(root).first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            return
        }

        jumpToParent(of: node, root: root)
    }

    private func focus(on nodeId: String?, selected node: GenreNode?) {
        focusedId = nodeId
        selectedNode = node
    }

    private func loadGenres() -> GenreNode? {
        guard let url = Bundle.module.url(forResource: "genres_tree", withExtension: "json") else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(GenreNode.self, from: data)
        } catch {
            print("Failed to load genres_tree.json: \(error)")
            return nil
        }
    }
}
