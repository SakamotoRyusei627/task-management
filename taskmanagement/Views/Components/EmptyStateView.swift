import SwiftUI

/// アプリの空状態を表示する共通コンポーネント
/// - Parameters:
///   - systemImage: SF Symbols 名（例: "checklist"）
///   - title: メインテキスト
///   - spacing: 縦の間隔
///   - iconSize: アイコンサイズ
struct EmptyStateView: View {
    var systemImage: String = "checklist"
    var title: String = "はじめてのタスクを追加しよう"
    var spacing: CGFloat = 12
    var iconSize: CGFloat = 40

    var body: some View {
        VStack(spacing: spacing) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize))
                .foregroundStyle(.tertiary)
            Text(title)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }
}

#Preview {
    // プレビュー用（任意）
    EmptyStateView()
}
