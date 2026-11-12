import SwiftUI

/// Floating rest countdown: draining ring, remaining time, what comes next,
/// and −15 / +15 / skip.
struct RestTimerBar: View {
    let timer: RestTimer
    /// "Satz 2 · Dips"
    var upNext: String?

    var body: some View {
        if let start = timer.startDate, let end = timer.endDate, start <= end {
            HStack(spacing: 12) {
                ring(start: start, end: end)

                VStack(alignment: .leading, spacing: 1) {
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Group {
                        if let upNext {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.forward")
                                Text(upNext)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Als Nächstes: \(upNext)")
                        } else {
                            Text("Pause")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 4)

                HStack(spacing: 6) {
                    adjustButton("−15", by: -15, label: "15 Sekunden weniger")
                    adjustButton("+15", by: 15, label: "15 Sekunden mehr")
                    Button {
                        timer.stop()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Pause überspringen")
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
        }
    }

    private func ring(start: Date, end: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let total = max(end.timeIntervalSince(start), 1)
            let remaining = min(max(end.timeIntervalSince(context.date), 0), total)
            ZStack {
                Circle()
                    .stroke(.fill.tertiary, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: remaining / total)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: remaining)
                Image(systemName: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }

    private func adjustButton(_ title: String, by seconds: Int, label: String) -> some View {
        Button {
            timer.adjust(by: seconds)
        } label: {
            Text(title)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
    }
}
