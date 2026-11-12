import SwiftUI

struct RestTimerBar: View {
    let timer: RestTimer

    var body: some View {
        if let start = timer.startDate, let end = timer.endDate, start <= end {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Pause").font(.caption).foregroundStyle(.secondary)
                        Text(timerInterval: start...end, countsDown: true)
                            .font(.title.bold())
                            .monospacedDigit()
                    }
                    Spacer()
                    Button("−15 s") { timer.adjust(by: -15) }
                        .buttonStyle(.bordered)
                    Button("+15 s") { timer.adjust(by: 15) }
                        .buttonStyle(.bordered)
                    Button {
                        timer.stop()
                    } label: {
                        Image(systemName: "forward.end.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Pause überspringen")
                }
                ProgressView(timerInterval: start...end, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        }
    }
}
