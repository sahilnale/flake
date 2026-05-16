import SwiftUI

struct FlakeNavBar: View {
    @Binding var selected: AppState.Tab
    @Environment(\.flakeTheme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppState.Tab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selected = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .regular))
                            .symbolVariant(selected == tab ? .fill : .none)
                        Text(tab.label)
                            .font(.mono(10))
                    }
                    .foregroundStyle(selected == tab ? theme.g1 : Color.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
        .background(.ultraThinMaterial.opacity(0.95))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
    }
}
