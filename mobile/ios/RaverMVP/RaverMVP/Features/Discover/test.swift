//
//  test.swift
//  RaverMVP
//
//  Created by 小小黑 on 2026/4/9.
//

import SwiftUI

struct User {
    let name: String
    let avatarSystemImage: String
}

struct Category: Identifiable, Hashable {
    let id = UUID()
    let title: String
}

struct SpotifyHomeView: View {
    @State private var currentUser: User? = User(name: "Nick", avatarSystemImage: "person.crop.circle.fill")
    @State private var selectedCategory: Category?

    private let categories: [Category] = [
        Category(title: "All"),
        Category(title: "Music"),
        Category(title: "Podcasts"),
        Category(title: "Audiobooks")
    ]

    var body: some View {
        ZStack {
            Color(red: 1.0, green: 0.30, blue: 0.18)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(0..<12, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.black.opacity(0.12))
                            .frame(height: 110)
                            .overlay(alignment: .leading) {
                                HStack(spacing: 14) {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.black.opacity(0.22))
                                        .frame(width: 72, height: 72)

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Playlist \(index + 1)")
                                            .font(.headline)
                                            .foregroundStyle(.white)

                                        Text("Mock content for reproduction")
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.85))
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            headerWithBackground
        }
        .task {
            await getData()
        }
    }

    private var headerWithBackground: some View {
        header
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(
                Color(red: 1.0, green: 0.30, blue: 0.18)
                    .ignoresSafeArea()
            )
    }

    private var header: some View {
    HStack(spacing: 8) {
        avatarView

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected(category) ? .black.opacity(0.95) : .black.opacity(0.78))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.22))
                .frame(width: 30, height: 30)

            if let currentUser {
                Image(systemName: currentUser.avatarSystemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.trailing, 2)
    }

    private func isSelected(_ category: Category) -> Bool {
        selectedCategory == nil ? category.title == "All" : selectedCategory == category
    }

    private func getData() async {
        try? await Task.sleep(nanoseconds: 250_000_000)
        currentUser = User(name: "Nick", avatarSystemImage: "person.crop.circle.fill")
        selectedCategory = categories.first
    }
}

struct ContentView: View {
    var body: some View {
        SpotifyHomeView()
    }
}

#Preview {
    ContentView()
}


struct SpotifyHomeViewReproApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
