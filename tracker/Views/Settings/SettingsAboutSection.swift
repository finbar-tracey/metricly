import SwiftUI
import StoreKit

struct SettingsAboutSection: View {
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        Section {
            Button {
                sendFeedbackEmail()
            } label: {
                HStack(spacing: 12) {
                    settingsSectionIcon("envelope.fill", color: .blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Send Feedback").font(.subheadline.weight(.semibold))
                        Text("Report bugs or suggest features").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Button {
                requestReview()
            } label: {
                HStack(spacing: 12) {
                    settingsSectionIcon("star.fill", color: .yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rate on App Store").font(.subheadline.weight(.semibold))
                        Text("Help us with a quick review").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Link(destination: URL(string: "https://apps.apple.com/ie/app/metricly/id6760858258")!) {
                HStack(spacing: 12) {
                    settingsSectionIcon("arrow.up.forward.app.fill", color: .accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("View on App Store").font(.subheadline.weight(.semibold))
                        Text("Share with friends").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                }
            }
            Link(destination: URL(string: "https://gist.githubusercontent.com/finbar-tracey/926003a49594537367eeb27d077267de/raw")!) {
                HStack(spacing: 12) {
                    settingsSectionIcon("hand.raised.fill", color: .indigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Privacy Policy").font(.subheadline.weight(.semibold))
                        Text("How we handle your data").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("About")
        } footer: {
            Text("We read every piece of feedback. Thank you for helping improve Metricly!")
        }
    }

    private func sendFeedbackEmail() {
        let subject = "Metricly Feedback"
        let urlString = "mailto:finbartracey@gmail.com?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}
