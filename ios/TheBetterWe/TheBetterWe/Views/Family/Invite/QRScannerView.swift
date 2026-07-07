import SwiftUI
import VisionKit
import Vision
import PhotosUI

struct QRScannerView: View {
    var onComplete: ([FamilyMembership]) -> Void = { _ in }

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showPhotoPicker = false
    @State private var errorMessage: String? = nil
    @State private var isLookingUp = false
    @State private var joinTarget: (inviteCode: String, familyName: String)? = nil
    @State private var navigateToJoin = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DataScannerRepresentable(onCodeScanned: handleScanned)
                .ignoresSafeArea()

            SweepLineView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                    Spacer()
                }
                .padding(.top, 56)
                .padding(.leading, 20)

                if let err = errorMessage {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.red.opacity(0.85), in: Capsule())
                        .padding(.top, 16)
                }

                Spacer()

                Text("识别二维码")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.bottom, 12)

                HStack {
                    Spacer()
                    Button { showPhotoPicker = true } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.8))
                            Text("相册")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                    }
                    Spacer()
                }
                .background(.black.opacity(0.85))
                .padding(.bottom, 34)
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task { await scanAlbumPhoto(item) }
        }
        .navigationDestination(isPresented: $navigateToJoin) {
            if let target = joinTarget {
                JoinFamilyView(
                    inviteCode: target.inviteCode,
                    familyName: target.familyName,
                    onComplete: onComplete
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea()
    }

    // MARK: - Code handling

    private func handleScanned(_ raw: String) {
        guard !isLookingUp else { return }
        guard let code = extractCode(from: raw) else {
            errorMessage = String(localized: "无效的邀请码")
            return
        }
        isLookingUp = true
        errorMessage = nil
        Task {
            do {
                let preview = try await FamilyService.lookupByInviteCode(code)
                await MainActor.run {
                    joinTarget = (inviteCode: code, familyName: preview.familyName)
                    navigateToJoin = true
                    isLookingUp = false
                }
            } catch FamilyError.notFound {
                await MainActor.run {
                    errorMessage = String(localized: "无效的邀请码")
                    isLookingUp = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLookingUp = false
                }
            }
        }
    }

    private func extractCode(from raw: String) -> String? {
        guard let url = URL(string: raw),
              url.scheme == "thebetterwe",
              url.host == "join",
              let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                  .queryItems?.first(where: { $0.name == "code" })?.value
        else { return nil }
        return code
    }

    private func scanAlbumPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else { return }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        guard let payload = request.results?.first?.payloadStringValue else {
            await MainActor.run { errorMessage = String(localized: "未找到二维码") }
            return
        }
        await MainActor.run { handleScanned(payload) }
    }
}

// MARK: - Sweep line animation

private struct SweepLineView: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.green.opacity(0), .green.opacity(0.9), .green.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 3)
                .offset(y: offset)
                .onAppear {
                    offset = 0
                    withAnimation(
                        .linear(duration: 2.4)
                        .repeatForever(autoreverses: true)
                    ) {
                        offset = h - 3
                    }
                }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - DataScanner wrapper

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighlightingEnabled: false
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCodeScanned: onCodeScanned) }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCodeScanned: (String) -> Void
        private var didFire = false

        init(onCodeScanned: @escaping (String) -> Void) { self.onCodeScanned = onCodeScanned }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd newItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !didFire else { return }
            for item in newItems {
                if case .barcode(let b) = item, let str = b.payloadStringValue {
                    didFire = true
                    dataScanner.stopScanning()
                    onCodeScanned(str)
                    return
                }
            }
        }
    }
}
