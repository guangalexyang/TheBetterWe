import SwiftUI
import CoreImage
import Photos

struct InviteSheet: View {
    let membership: FamilyMembership

    @State private var inviteCode: String? = nil
    @State private var qrImage: UIImage? = nil
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var errorMessage: String? = nil
    @State private var savedToPhotos = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(theme.cardBorder)
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Header row
            HStack {
                Text("邀请家庭成员")
                    .font(.headline.bold())
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color(.systemGray5), in: Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // QR or spinner
            Group {
                if isLoading {
                    ProgressView()
                        .frame(width: 192, height: 192)
                } else if let img = qrImage {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 192, height: 192)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: theme.primaryAccent.opacity(0.15), radius: 12)
                }
            }

            // Refresh button
            Button {
                Task { await refresh() }
            } label: {
                HStack(spacing: 6) {
                    if isRefreshing {
                        ProgressView().scaleEffect(0.75)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                    }
                    Text("刷新二维码")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(theme.primaryAccent)
            }
            .disabled(isRefreshing)
            .padding(.top, 12)

            // Family label
            VStack(spacing: 4) {
                Text(verbatim: membership.familyName)
                    .font(.headline)
                Text("扫描二维码即可申请加入此家庭")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 10) {
                Button { shareQR() } label: {
                    Label("分享二维码", systemImage: "square.and.arrow.up")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(theme.primaryAccent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .disabled(qrImage == nil)

                Button { saveToPhotos() } label: {
                    Label(
                        savedToPhotos ? "已保存 Saved" : "存储到相册",
                        systemImage: savedToPhotos ? "checkmark" : "arrow.down.to.line"
                    )
                    .font(.body.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(savedToPhotos ? Color.green.opacity(0.15) : theme.cardSurface)
                    .foregroundStyle(savedToPhotos ? .green : .primary)
                    .overlay(Capsule().stroke(savedToPhotos ? Color.green.opacity(0.4) : theme.cardBorder, lineWidth: 1))
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: 0.25), value: savedToPhotos)
                }
                .disabled(qrImage == nil || savedToPhotos)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(theme.pageBg)
        .task { await load() }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let code = try await FamilyService.getInviteCode(familyId: membership.familyId)
            inviteCode = code
            qrImage = generateQR(from: code)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func refresh() async {
        isRefreshing = true
        errorMessage = nil
        savedToPhotos = false
        do {
            let code = try await FamilyService.refreshInviteCode(familyId: membership.familyId)
            inviteCode = code
            qrImage = generateQR(from: code)
        } catch {
            errorMessage = error.localizedDescription
        }
        isRefreshing = false
    }

    private func generateQR(from code: String) -> UIImage? {
        guard let data = "thebetterwe://join?code=\(code)".data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        guard let output = filter.outputImage?.transformed(by: transform) else { return nil }
        let context = CIContext()
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func shareQR() {
        guard let image = qrImage,
              let scene = UIApplication.shared.connectedScenes
                  .compactMap({ $0 as? UIWindowScene }).first,
              let window = scene.windows.first else { return }
        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        window.rootViewController?.present(av, animated: true)
    }

    private func saveToPhotos() {
        guard let image = qrImage else { return }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { success, _ in
            guard success else { return }
            DispatchQueue.main.async {
                withAnimation { savedToPhotos = true }
            }
        })
    }
}
