import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct OnboardingGetStartedPage: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appServices) private var appServices

    @Binding var showingImport: Bool
    @Binding var pendingImportPreview: ImportHelper.ImportPreview?
    @Binding var pendingImportSuccess: OnboardingImportSuccess?
    @Binding var importErrorMessage: String?

    let onApplySettings: () -> Void
    let onComplete: () -> Void
    let onFinishWithImport: (Int) -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: AppTheme.Gradients.recovery,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle().fill(.white.opacity(0.07)).frame(width: 280).offset(x: 100, y: -160)
            Circle().fill(.white.opacity(0.04)).frame(width: 160).offset(x: -80, y: 200)

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle().fill(.white.opacity(0.15)).frame(width: 130, height: 130)
                    Circle().fill(.white.opacity(0.10)).frame(width: 100, height: 100)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 10) {
                    Text("You're all set.")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("Log your first workout —\nMetricly will start learning your\nrecovery patterns from day one.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        showingImport = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "tray.and.arrow.down.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Import history (Strong / Hevy)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .tracking(0.3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .foregroundStyle(Color(red: 0.12, green: 0.68, blue: 0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    }
                    .buttonStyle(.pressableCard)

                    Button {
                        onApplySettings()
                        onComplete()
                        dismiss()
                    } label: {
                        Text("Start fresh")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .tracking(0.3)
                            .foregroundStyle(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 22)
                    }
                    .buttonStyle(.pressableCard)
                }
            }
            .padding(32)
        }
        .fileImporter(
            isPresented: $showingImport,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    switch try ImportHelper.plan(from: url) {
                    case .preview(let preview):
                        pendingImportPreview = preview
                    case .metriclyDirect:
                        let count = try ImportHelper.importCSV(from: url, into: modelContext)
                        importErrorMessage = nil
                        onFinishWithImport(count)
                    }
                } catch {
                    importErrorMessage = error.localizedDescription
                }
            case .failure(let error):
                importErrorMessage = error.localizedDescription
            }
        }
        .sheet(item: $pendingImportPreview) { preview in
            ImportPreviewSheet(
                preview: preview,
                onImport: {
                    let count = ImportHelper.commitPreview(preview, into: modelContext)
                    pendingImportPreview = nil
                    if count > 0 {
                        let analysis = ImportAnalyzer.analyze(preview.workouts)
                        pendingImportSuccess = OnboardingImportSuccess(analysis: analysis)
                    } else {
                        onFinishWithImport(0)
                    }
                },
                onCancel: {
                    pendingImportPreview = nil
                }
            )
        }
        .sheet(item: $pendingImportSuccess) { presentation in
            ImportSuccessSheet(
                analysis: presentation.analysis,
                onStartRecommended: {
                    pendingImportSuccess = nil
                    onApplySettings()
                    onComplete()
                    dismiss()
                    appServices.router.openTrainingTab()
                },
                onDismiss: {
                    pendingImportSuccess = nil
                    onApplySettings()
                    onComplete()
                    dismiss()
                }
            )
        }
        .alert("Import Failed",
               isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
               )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
    }
}

/// Identifiable wrapper so SwiftUI's `sheet(item:)` can drive the
/// post-import success sheet from a freshly-computed `ImportAnalysis`
/// inside the onboarding flow. Mirrors the wrapper in SettingsView —
/// each surface keeps its own so the types don't have to be public.
struct OnboardingImportSuccess: Identifiable {
    let id = UUID()
    let analysis: ImportAnalysis
}
