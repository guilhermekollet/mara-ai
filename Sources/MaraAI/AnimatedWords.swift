import SwiftUI

/// Text that builds up word by word, like the website demo: each new word fades in with a slight
/// blur, and the words already on screen neither move nor flicker.
struct AnimatedWords: View {
    let text: String
    let size: CGFloat
    let color: Color
    var centered = false

    var body: some View {
        let shown = Array(text.split(separator: " ").map(String.init).enumerated())
        WordFlow(centered: centered, spacing: size * 0.27, lineSpacing: size * 0.22) {
            // Identity is the word's position in the sentence: when recognition corrects an earlier
            // word, its text changes in place; only new positions get the entrance animation.
            ForEach(shown, id: \.offset) { _, word in
                AppearingWord(word: word, size: size, color: color)
            }
        }
    }
}

private struct AppearingWord: View {
    let word: String
    let size: CGFloat
    let color: Color
    @State private var shown = false

    var body: some View {
        Text(word)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(color)
            .fixedSize()
            .opacity(shown ? 1 : 0)
            .blur(radius: shown ? 0 : 5)
            .offset(y: shown ? 0 : 4)
            .onAppear {
                withAnimation(.easeOut(duration: 0.45)) { shown = true }
            }
    }
}

/// Wraps the words into lines, left-aligned or centered. Positions change instantly, with no
/// animation: only each word's entrance is animated.
private struct WordFlow: Layout {
    let centered: Bool
    let spacing: CGFloat
    let lineSpacing: CGFloat

    private func lines(for subviews: Subviews, width: CGFloat) -> [(items: [(index: Int, size: CGSize)], width: CGFloat, height: CGFloat)] {
        var result: [(items: [(index: Int, size: CGSize)], width: CGFloat, height: CGFloat)] = []
        var current: [(index: Int, size: CGSize)] = []
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let needed = current.isEmpty ? size.width : lineWidth + spacing + size.width
            if !current.isEmpty, needed > width {
                result.append((current, lineWidth, lineHeight))
                current = [(index, size)]
                lineWidth = size.width
                lineHeight = size.height
            } else {
                current.append((index, size))
                lineWidth = needed
                lineHeight = max(lineHeight, size.height)
            }
        }
        if !current.isEmpty { result.append((current, lineWidth, lineHeight)) }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = lines(for: subviews, width: width)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        let widest = rows.map(\.width).max() ?? 0
        return CGSize(width: width.isFinite ? width : widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in lines(for: subviews, width: bounds.width) {
            var x = bounds.minX + (centered ? (bounds.width - row.width) / 2 : 0)
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (row.height - item.size.height) / 2), proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }
}

