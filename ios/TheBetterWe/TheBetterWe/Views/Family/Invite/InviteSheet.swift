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

            // QR card or spinner
            Group {
                if isLoading {
                    ProgressView()
                        .frame(width: 240, height: 280)
                } else if let img = qrImage {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
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
            .padding(.top, 14)

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
                        savedToPhotos ? "已保存" : "存储到相册",
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
            qrImage = generateQRCard(from: code, familyName: membership.familyName)
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
            qrImage = generateQRCard(from: code, familyName: membership.familyName)
        } catch {
            errorMessage = error.localizedDescription
        }
        isRefreshing = false
    }

    // MARK: - QR card generation

    private func generateQRCard(from code: String, familyName: String) -> UIImage? {
        guard let qrMatrix = makeQRMatrix(from: code) else { return nil }

        let scale: CGFloat = 3
        let qrSize: CGFloat = 240
        let hPad: CGFloat = 24
        let topPad: CGFloat = 24
        let namePad: CGFloat = 16   // gap between QR and name
        let nameHeight: CGFloat = 22
        let subtitleHeight: CGFloat = 18
        let bottomPad: CGFloat = 20
        let cardW = qrSize + hPad * 2
        let cardH = topPad + qrSize + namePad + nameHeight + subtitleHeight + bottomPad

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cardW, height: cardH), format: format)

        return renderer.image { _ in
            let ctx = UIGraphicsGetCurrentContext()!

            // White card background
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: cardW, height: cardH))

            // QR matrix (no interpolation — pixel-perfect)
            let qrRect = CGRect(x: hPad, y: topPad, width: qrSize, height: qrSize)
            ctx.interpolationQuality = .none
            qrMatrix.draw(in: qrRect)

            // Logo: white border circle, then gradient circle, then "佳" text
            let logoD: CGFloat = qrSize * 0.22
            let logoX = hPad + (qrSize - logoD) / 2
            let logoY = topPad + (qrSize - logoD) / 2
            let logoRect = CGRect(x: logoX, y: logoY, width: logoD, height: logoD)

            let borderD = logoD + 8
            let borderRect = CGRect(
                x: hPad + (qrSize - borderD) / 2,
                y: topPad + (qrSize - borderD) / 2,
                width: borderD, height: borderD
            )
            UIColor.white.setFill()
            ctx.fillEllipse(in: borderRect)

            ctx.saveGState()
            UIBezierPath(ovalIn: logoRect).addClip()
            let gradColors = [
                UIColor(red: 240/255, green: 112/255, blue: 74/255, alpha: 1).cgColor,
                UIColor(red: 232/255, green: 93/255, blue: 122/255, alpha: 1).cgColor,
            ] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradColors, locations: [0, 1])!
            ctx.drawLinearGradient(
                grad,
                start: CGPoint(x: logoRect.minX, y: logoRect.minY),
                end: CGPoint(x: logoRect.maxX, y: logoRect.maxY),
                options: []
            )
            ctx.restoreGState()

            let logoFont = UIFont.systemFont(ofSize: logoD * 0.52, weight: .bold)
            let logoAttrs: [NSAttributedString.Key: Any] = [.font: logoFont, .foregroundColor: UIColor.white]
            let logoText = "佳"
            let logoTextSize = logoText.size(withAttributes: logoAttrs)
            logoText.draw(at: CGPoint(
                x: logoRect.midX - logoTextSize.width / 2,
                y: logoRect.midY - logoTextSize.height / 2
            ), withAttributes: logoAttrs)

            // Family name
            let nameY = topPad + qrSize + namePad
            let nameFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
            let nameAttrs: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: UIColor.black]
            let nameSize = familyName.size(withAttributes: nameAttrs)
            familyName.draw(at: CGPoint(
                x: cardW / 2 - nameSize.width / 2,
                y: nameY
            ), withAttributes: nameAttrs)

            // Subtitle
            let subFont = UIFont.systemFont(ofSize: 11, weight: .regular)
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: subFont,
                .foregroundColor: UIColor(white: 0.55, alpha: 1)
            ]
            let subText = String(localized: "扫码加入")
            let subSize = subText.size(withAttributes: subAttrs)
            subText.draw(at: CGPoint(
                x: cardW / 2 - subSize.width / 2,
                y: nameY + nameHeight
            ), withAttributes: subAttrs)
        }
    }

    private func makeQRMatrix(from code: String) -> UIImage? {
        guard let data = "thebetterwe://join?code=\(code)".data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")  // H = 30% — required for logo overlay
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
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else { return }
        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(av, animated: true)
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
