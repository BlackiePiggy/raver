import SwiftUI

struct ComposePostView: View {
    @EnvironmentObject private var appState: AppState

    @State private var text = ""
    @State private var imageURLInput = ""
    @State private var imageURLs: [String] = []
    @State private var isSending = false
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                TextEditor(text: $text)
                    .frame(minHeight: 180)
                    .padding(10)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack {
                    TextField("图片 URL（可选）", text: $imageURLInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button("添加") {
                        let trimmed = imageURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        imageURLs.append(trimmed)
                        imageURLInput = ""
                    }
                    .buttonStyle(.borderedProminent)
                }

                if !imageURLs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(imageURLs, id: \.self) { url in
                                Text(url)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(RaverTheme.card)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                Button {
                    Task {
                        isSending = true
                        defer { isSending = false }
                        do {
                            _ = try await appState.service.createPost(
                                input: CreatePostInput(content: text, images: imageURLs)
                            )
                            text = ""
                            imageURLs = []
                            toast = "发布成功"
                        } catch {
                            toast = error.localizedDescription
                        }
                    }
                } label: {
                    if isSending {
                        ProgressView().tint(.white)
                    } else {
                        Text("发布动态")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)

                Spacer()
            }
            .padding(16)
            .foregroundStyle(RaverTheme.primaryText)
            .background(RaverTheme.background)
            .navigationTitle("发布")
            .alert("提示", isPresented: Binding(
                get: { toast != nil },
                set: { if !$0 { toast = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(toast ?? "")
            }
        }
    }
}
