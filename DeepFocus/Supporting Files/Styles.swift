import SwiftUI

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.white.opacity(0.8) : Color.white)
            )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(configuration.isPressed ? 0.4 : 0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
            )
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundColor(Color.red.opacity(configuration.isPressed ? 0.6 : 0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.red.opacity(0.12))
            )
    }
}

// MARK: - Toggle Styles

struct VisibleCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            ZStack {
                if configuration.isOn {
                    Image(systemName: "checkmark.square.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        .frame(width: 16, height: 16)
                }
            }
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .onTapGesture {
                configuration.isOn.toggle()
            }
            configuration.label
        }
    }
}

// MARK: - View Modifiers

private struct CaptionLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white.opacity(0.45))
            .kerning(1.5)
            .textCase(.uppercase)
    }
}

extension View {
    func captionLabel() -> some View {
        modifier(CaptionLabel())
    }
}
