import SwiftUI

struct ActiveTimerBanner: View {
    @EnvironmentObject var store: AppStore
    let entry: TimeEntry
    let task: Task
    let project: Project

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            // Pulsing dot
            ZStack {
                Circle()
                    .fill(Color.projectColor(named: project.color).opacity(0.25))
                    .frame(width: 20, height: 20)
                    .scaleEffect(pulse ? 1.4 : 1.0)
                    .opacity(pulse ? 0 : 1)
                Circle()
                    .fill(Color.projectColor(named: project.color))
                    .frame(width: 8, height: 8)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(task.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(project.name)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.duration.formatted)
                .font(.system(size: 15, weight: .bold).monospacedDigit())
                .id(store.tick)

            Button {
                store.stopTracking()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
