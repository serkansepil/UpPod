import AppKit
import SwiftUI

// MARK: - Helpers

private func fmtDuration(_ s: Double) -> String {
    L10n.shortDuration(s)
}

private func stateLabel(_ s: PostureState) -> String {
    L10n.stateLabel(s)
}

private func stateColor(_ s: PostureState) -> Color {
    switch s {
    case .good:   return Theme.good
    case .slight: return Theme.slight
    case .poor:   return Theme.poor
    case .paused: return .secondary
    }
}

private func scoreColor(_ score: Int) -> Color {
    switch score {
    case 85...:   return Theme.good
    case 70..<85: return Theme.goodSoft
    case 50..<70: return Theme.slight
    default:      return Theme.poor
    }
}

private func scoreBand(_ score: Int) -> String {
    L10n.scoreBand(score)
}

private func weekScoreBand(_ score: Int?) -> String {
    guard let score else { return L10n.text("Veri yok", "No data") }
    switch score {
    case 80...: return L10n.text("İyi", "Good")
    case 60..<80: return L10n.text("Orta", "Fair")
    default: return L10n.text("Kötü", "Poor")
    }
}

private func weekScoreColor(_ score: Int?) -> Color {
    guard let score else { return .secondary.opacity(0.45) }
    switch score {
    case 80...: return Theme.good
    case 60..<80: return Theme.slight
    default: return Theme.poor
    }
}

private func localizedWeekday(_ label: String) -> String {
    switch label.lowercased() {
    case "mon", "pzt": return L10n.text("Pzt", "Mon")
    case "tue", "sal": return L10n.text("Sal", "Tue")
    case "wed", "çar", "car": return L10n.text("Çar", "Wed")
    case "thu", "per": return L10n.text("Per", "Thu")
    case "fri", "cum": return L10n.text("Cum", "Fri")
    case "sat", "cmt": return L10n.text("Cmt", "Sat")
    case "sun", "paz": return L10n.text("Paz", "Sun")
    default: return label
    }
}

private extension View {
    func popoverSurface(cornerRadius: CGFloat = 13) -> some View {
        padding(14)
            .background(Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Today's distribution (single neat stacked bar)

private struct SegmentedBar: View {
    let good: Double, slight: Double, poor: Double
    private var total: Double { max(good + slight + poor, 0.001) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                HStack(spacing: 0) {
                    seg(good, Theme.good, w)
                    seg(slight, Theme.slight, w)
                    seg(poor, Theme.poor, w)
                }
                .clipShape(Capsule())
            }
        }
        .frame(height: 7)
    }

    @ViewBuilder private func seg(_ v: Double, _ c: Color, _ w: CGFloat) -> some View {
        if v > 0 { Rectangle().fill(c).frame(width: max(0, w * v / total)) }
    }
}

// MARK: - Score ring

private struct ScoreRing: View {
    let score: Int?
    var size: CGFloat = 98

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: 9)
            if let s = score {
                Circle()
                    .trim(from: 0, to: CGFloat(s) / 100)
                    .stroke(scoreColor(s), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(s)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(L10n.text("puan", "score"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("–")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct WeeklyRings: View {
    let days: [DayStat]

    private var hasAnyScore: Bool {
        days.contains { $0.score != nil }
    }

    var body: some View {
        Group {
            if days.isEmpty || !hasAnyScore {
                Text(L10n.text(
                    "Birkaç gün kullandıktan sonra haftalık skorların burada görünür.",
                    "Use it for a few days and your weekly scores will appear here."
                ))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } else {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(days) { day in
                        WeeklyDayRing(day: day)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

private struct WeeklyDayRing: View {
    let day: DayStat

    var body: some View {
        VStack(spacing: 6) {
            Text(localizedWeekday(day.label))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 4)
                if let score = day.score {
                    Circle()
                        .trim(from: 0, to: CGFloat(max(min(score, 100), 0)) / 100)
                        .stroke(weekScoreColor(score), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Text(day.score.map(String.init) ?? "–")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(day.score == nil ? .secondary : .primary)
                    .monospacedDigit()
            }
            .frame(width: 34, height: 34)
            Text(weekScoreBand(day.score))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(day.score == nil ? .secondary : weekScoreColor(day.score))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 42)
    }
}

private struct PostureSpineIcon: View {
    var body: some View {
        Group {
            if let image = postureIconImage() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "figure.stand")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.good)
                    .frame(width: 58, height: 58)
                    .background(Theme.good.opacity(0.14), in: Circle())
            }
        }
        .frame(width: 58, height: 58)
    }

    private func postureIconImage() -> NSImage? {
        AppImage.png("posture-spine-icon")
    }
}

private struct StatusNotice: View {
    let icon: String
    let title: String
    let message: String
    var tint: Color = Theme.slight
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .controlSize(.small)
                        .padding(.top, 1)
                }
            }
            Spacer(minLength: 0)
        }
        .popoverSurface(cornerRadius: 12)
    }
}

// MARK: - Popover

struct PopoverContentView: View {
    @ObservedObject var engine: PostureEngine
    var onStartExercise: () -> Void = {}
    var onCheckForUpdates: () -> Void = {}
    @State private var showStats = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            liveHeader
            if let notice {
                StatusNotice(icon: notice.icon, title: notice.title, message: notice.message,
                             tint: notice.tint, actionTitle: notice.actionTitle, action: notice.action)
            }
            Divider().opacity(0.65)
            todayCard
            Divider().opacity(0.65)
            statsCard
            exerciseButton
            sensitivityCard
            footer
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .frame(width: 390)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // Live status (right now)
    private var liveHeader: some View {
        HStack(spacing: 14) {
            PostureSpineIcon()
            VStack(alignment: .leading, spacing: 4) {
                Text(stateLabel(engine.state))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            Spacer()
        }
    }

    private var permissionDenied: Bool {
        engine.authorization == .denied || engine.authorization == .restricted
    }

    private func openMotionSettings() {
        // Opens System Settings → Privacy & Security (Motion & Fitness anchor when available).
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Motion") {
            NSWorkspace.shared.open(url)
        }
    }

    private var subtitle: String {
        if !engine.motionAvailable { return L10n.text("Hareket sensörü kullanılamıyor", "Motion sensor unavailable") }
        if permissionDenied { return L10n.text("Hareket izni kapalı", "Motion access is off") }
        if !engine.connected { return L10n.text("AirPods bekleniyor", "Waiting for AirPods") }
        if engine.calibratedAt == nil { return L10n.text("Dik otur ve kalibre et", "Sit upright and calibrate") }
        let format = L10n.text("Öne eğim %.0f° · boyun yükü ~%.0f kg", "Forward tilt %.0f° · neck load ~%.0f kg")
        return String(format: format, engine.liveFlexionDeg, engine.loadKg)
    }

    private struct Notice {
        let icon: String
        let title: String
        let message: String
        var tint: Color = Theme.slight
        var actionTitle: String? = nil
        var action: (() -> Void)? = nil
    }

    private var notice: Notice? {
        if !engine.motionAvailable {
            return Notice(
                icon: "sensor.tag.radiowaves.forward",
                title: L10n.text("Hareket sensörü kullanılamıyor", "Motion sensor unavailable"),
                message: L10n.text(
                    "Uyumlu AirPods kullandığından ve Motion & Fitness izninin açık olduğundan emin ol.",
                    "Use compatible AirPods and allow Motion & Fitness in System Settings."
                )
            )
        }
        if permissionDenied {
            return Notice(
                icon: "hand.raised.slash",
                title: L10n.text("Hareket izni kapalı", "Motion access is off"),
                message: L10n.text(
                    "UpPod baş eğimini ölçemiyor. Sistem Ayarları › Gizlilik ve Güvenlik › Hareket ve Fitness'tan UpPod'a izin ver.",
                    "UpPod can't read head tilt. Allow UpPod under System Settings › Privacy & Security › Motion & Fitness."
                ),
                tint: Theme.poor,
                actionTitle: L10n.text("Sistem Ayarları'nı aç", "Open System Settings"),
                action: openMotionSettings
            )
        }
        if !engine.connected {
            return Notice(
                icon: "airpodspro",
                title: L10n.text("AirPods bağlantısı bekleniyor", "Waiting for AirPods"),
                message: L10n.text(
                    "AirPods'u tak ve Bluetooth bağlantısını kontrol et. Bağlanınca takip otomatik başlar.",
                    "Wear your AirPods and check Bluetooth. Tracking starts automatically when they connect."
                )
            )
        }
        if engine.calibratedAt == nil {
            return Notice(
                icon: "scope",
                title: L10n.text("Kalibrasyon gerekiyor", "Calibration needed"),
                message: L10n.text(
                    "Dik otur, birkaç saniye sabit kal ve kalibre et.",
                    "Sit upright, stay still for a few seconds, then calibrate."
                )
            )
        }
        return nil
    }

    // Today (score + distribution)
    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 22) {
                ScoreRing(score: engine.score)
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.text("Bugün", "Today"))
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                        if let s = engine.score {
                            Text(scoreBand(s))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(scoreColor(s))
                        }
                    }
                    SegmentedBar(good: engine.goodSec, slight: engine.slightSec, poor: engine.poorSec)
                }
            }
            HStack(alignment: .top, spacing: 24) {
                legend(Theme.good, engine.goodSec, L10n.text("İyi", "Good"))
                legend(Theme.slight, engine.slightSec, L10n.text("Orta", "Moderate"))
                legend(Theme.poor, engine.poorSec, L10n.text("Kötü", "Poor"))
            }
        }
    }

    private func legend(_ c: Color, _ sec: Double, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Circle().fill(c).frame(width: 8, height: 8)
                Text(fmtDuration(sec))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1).fixedSize(horizontal: true, vertical: false)
        }
    }

    // Statistics (collapsible)
    private var statsCard: some View {
        VStack(alignment: .leading, spacing: showStats ? 13 : 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showStats.toggle() }
            } label: {
                HStack {
                    Text(L10n.text("Son 7 gün", "Last 7 days"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showStats ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showStats {
                WeeklyRings(days: engine.history)
            }
        }
        .padding(.vertical, 2)
    }

    // Start exercise mode
    private var exerciseButton: some View {
        Button { onStartExercise() } label: {
            Label(L10n.text("Boyun egzersizleri", "Neck exercises"), systemImage: "figure.cooldown")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(
            (engine.motionAvailable && engine.connected ? Theme.good : Color.secondary.opacity(0.45)),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .shadow(color: Theme.good.opacity(0.12), radius: 8, y: 3)
        .disabled(!engine.motionAvailable || !engine.connected)
    }

    // Sensitivity
    private var sensitivityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.text("Hassasiyet", "Sensitivity"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
                Text(L10n.sensitivityLabel(engine.sensitivity))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $engine.sensitivity, in: 0.7...1.6)
        }
        .padding(.top, 4)
    }

    // Footer
    private var footer: some View {
        VStack(alignment: .leading, spacing: 9) {
            Divider().opacity(0.65)
            HStack {
                if engine.calibrating {
                    HStack(spacing: 7) {
                        ProgressView().controlSize(.small)
                        Text(L10n.text("Sabit dur · kalibre ediliyor", "Hold still · calibrating"))
                            .font(.system(size: 13, weight: .medium))
                    }
                } else {
                    Button { engine.calibrate() } label: {
                        Label(engine.calibratedAt == nil ? L10n.text("Dik otur ve kalibre et", "Sit upright and calibrate") : L10n.text("Yeniden kalibre et", "Recalibrate"),
                              systemImage: "scope")
                    }
                    .controlSize(.small)
                    .disabled(!engine.connected)
                }
                Spacer()
                Button(L10n.text("Güncelle", "Update")) { onCheckForUpdates() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Button(L10n.text("Çıkış", "Quit")) { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            if let at = engine.calibratedAt {
                Text("\(L10n.text("Son kalibrasyon", "Last calibrated")) \(at.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
