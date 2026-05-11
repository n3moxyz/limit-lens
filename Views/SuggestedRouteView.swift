import SwiftUI

struct SuggestedRouteCard: View {
    var route: SuggestedRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: route.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggested Route")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(route.title)
                        .font(.headline)

                    Text(route.recommendation)
                        .font(.subheadline.weight(.medium))
                }

                Spacer()
            }

            Text(route.rationale)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Suggested route")
        .accessibilityValue("\(route.title). \(route.recommendation). \(route.rationale)")
        .accessibilityIdentifier("suggested-route-card")
    }

    private var tint: Color {
        SuggestedRouteColor.color(named: route.tintName)
    }
}

struct SuggestedRouteMini: View {
    var route: SuggestedRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(route.title, systemImage: route.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SuggestedRouteColor.color(named: route.tintName))

            Text(route.recommendation)
                .font(.caption.weight(.medium))
                .lineLimit(2)

            Text(route.rationale)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Suggested route")
        .accessibilityValue("\(route.title). \(route.recommendation). \(route.rationale)")
        .accessibilityIdentifier("menu-suggested-route")
    }
}

private enum SuggestedRouteColor {
    static func color(named name: String) -> Color {
        switch name {
        case "blue":
            return .blue
        case "green":
            return .green
        case "orange":
            return .orange
        case "purple":
            return .purple
        case "red":
            return .red
        default:
            return .secondary
        }
    }
}
