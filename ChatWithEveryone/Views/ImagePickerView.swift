import SwiftUI

struct ImagePickerView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.attachedImages.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.attachedImages) { img in
                            ZStack(alignment: .topTrailing) {
                                if let data = StorageService.shared.loadImageData(at: img.localFilePath),
                                   let nsImage = NSImage(data: data) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 80)
                                        .cornerRadius(8)
                                }
                                Button {
                                    viewModel.removeImage(img)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                }
                                .buttonStyle(.plain)
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 90)
                Divider()
            }
        }
    }
}
