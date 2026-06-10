import SwiftUI

struct LearnImagePreviewItem: Identifiable, Hashable {
    let id = UUID().uuidString
    let title: String
    let url: URL
}

struct LearnImagePreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let item: LearnImagePreviewItem

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ImageLoaderView(urlString: item.url.absoluteString, resizingMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Text(LT("图片加载失败", "图片加载失败", "画像の読み込みに失敗しました"))
                        .foregroundStyle(Color.white.opacity(0.85))
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 44)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
        .overlay(alignment: .topLeading) {
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.top, 18)
                .padding(.leading, 16)
        }
    }
}
