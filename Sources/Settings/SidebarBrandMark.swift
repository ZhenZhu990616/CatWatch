import SwiftUI

struct SidebarBrandMark: View {
    @Environment(\.colorScheme) private var colorScheme

    private var markOpacity: Double {
        colorScheme == .dark ? 0.76 : 0.64
    }

    private var markColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var facialFeatureColor: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        VStack(spacing: 4) {
            Canvas { context, size in
                let bounds = CGRect(origin: .zero, size: size)
                context.fill(
                    Path(CatBodyMark.swiftUIPath(in: bounds)),
                    with: .color(markColor)
                )

                let features = CatBodyMark.swiftUIFacialFeatures(in: bounds)
                let unit = size.width / 100
                context.stroke(
                    Path(features.mouth),
                    with: .color(facialFeatureColor),
                    style: StrokeStyle(lineWidth: 2.6 * unit, lineCap: .round, lineJoin: .round)
                )
                context.stroke(
                    Path(features.mouthStem),
                    with: .color(facialFeatureColor),
                    style: StrokeStyle(lineWidth: 2.6 * unit, lineCap: .round, lineJoin: .round)
                )
                context.stroke(
                    Path(features.whiskers),
                    with: .color(facialFeatureColor),
                    style: StrokeStyle(lineWidth: 2.25 * unit, lineCap: .round, lineJoin: .round)
                )
            }
            .frame(width: 96, height: 96)

            Text(AppVersion.marketing)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .opacity(markOpacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("CatGPT，版本 \(AppVersion.marketing)")
        .accessibilityAddTraits(.isImage)
    }
}
