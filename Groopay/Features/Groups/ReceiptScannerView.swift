import SwiftUI
import PhotosUI

struct ReceiptScannerView: View {
    let groupID: UUID
    let store: GroupsStore
    let currency: String
    let onComplete: ([ScannedReceiptItem]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.appFeedback) private var feedback

    @State private var scannedItems: [ScannedReceiptItem] = []
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showCamera = false
    @State private var scanner = ReceiptScanner()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                
                if scanner.isProcessing {
                    processingState
                } else if scannedItems.isEmpty {
                    emptyState
                } else {
                    itemList
                }

                if !scannedItems.isEmpty {
                    actionPanel
                }
            }
            .background(Color.background.ignoresSafeArea())
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in
                    if let image {
                        Task {
                            await scanner.scan(image: image)
                            processScannerResult()
                        }
                    }
                }
            }
            .onChange(of: selectedItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await scanner.scan(image: image)
                        processScannerResult()
                    }
                    selectedItem = nil
                }
            }
        }
    }

    private var header: some View {
        ZStack {
            Text("Fişten Ekle", comment: "OCR receipt scanner view title")
                .font(.display(18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.surfaceTinted)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var processingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(Color.primaryTheme)
                .scaleEffect(1.2)
            Text("Fiş işleniyor...", comment: "OCR scanning loader text")
                .font(.body(15, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.primaryTheme.opacity(0.8))
                
                Text("Fiş Okuma", comment: "OCR empty state title")
                    .font(.display(20, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                
                Text("Fişin fotoğrafını çekin veya galeriden seçin. Kalemler otomatik ayrıştırılacaktır.", comment: "OCR empty state description")
                    .font(.body(14))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let error = scanner.error {
                Text(error)
                    .font(.body(13))
                    .foregroundStyle(Color.debt)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Fotoğraf Çek", comment: "Take photo button")
                    }
                    .font(.body(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.primaryTheme)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
                }
                .purpleTintedShadow()

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Galeriden Seç", comment: "Choose from library button")
                    }
                    .font(.body(15, weight: .semibold))
                    .foregroundStyle(Color.primaryTheme)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
                    .overlay(
                        RoundedRectangle(cornerRadius: ThemeRadius.button)
                            .stroke(Color.primaryTheme.opacity(0.2), lineWidth: 1)
                    )
                }

                Button {
                    scannedItems = [ScannedReceiptItem(name: "", amountMinor: 0)]
                } label: {
                    Text("Manuel Kalem Ekle", comment: "Add manual line item button")
                        .font(.body(14, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.vertical, 8)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var itemList: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let snapshot = store.snapshot(groupID) {
                    let members = snapshot.activeMembers
                    
                    ForEach($scannedItems) { $item in
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                TextField("Kalem adı (örn: Hamburger)", text: $item.name)
                                    .font(.body(15, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                    .padding(.horizontal, 8)
                                    .frame(maxHeight: .infinity)
                                    .background(Color.surfaceTinted)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                HStack(spacing: 4) {
                                    TextField("0.00", text: Binding(
                                        get: {
                                            item.amountMinor == 0 ? "" : String(format: "%.2f", Double(item.amountMinor) / 100.0)
                                        },
                                        set: { newValue in
                                            let parsed = parseMoneyInputToMinor(newValue, currency: currency)
                                            item.amountMinor = parsed
                                        }
                                    ))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.display(16, weight: .bold))
                                    .foregroundStyle(Color.primaryTheme)
                                    .frame(width: 80)
                                    
                                    Text(currency.uppercased())
                                        .font(.body(12, weight: .semibold))
                                        .foregroundStyle(Color.textSecondary)
                                }
                                
                                Button {
                                    if let idx = scannedItems.firstIndex(where: { $0.id == item.id }) {
                                        scannedItems.remove(at: idx)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(Color.debt)
                                        .frame(width: 32, height: 32)
                                        .background(Color.debt.opacity(0.1))
                                        .clipShape(Circle())
                                }
                            }
                            .frame(height: 38)
                            
                            // Member selection row
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Bölüşecek Üyeler", comment: "Assignment section title")
                                    .font(.body(11, weight: .semibold))
                                    .foregroundStyle(Color.textSecondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(members) { member in
                                            let selected = item.assignedMemberIds.contains(member.id)
                                            Button {
                                                if selected {
                                                    item.assignedMemberIds.remove(member.id)
                                                } else {
                                                    item.assignedMemberIds.insert(member.id)
                                                }
                                            } label: {
                                                HStack(spacing: 4) {
                                                    GradientAvatar(
                                                        name: member.displayName,
                                                        color: member.avatarColor,
                                                        size: 24
                                                    )
                                                    Text(member.displayName)
                                                        .font(.body(12, weight: .semibold))
                                                }
                                                .foregroundStyle(selected ? .white : Color.textSecondary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(selected ? Color.primaryTheme : Color.surface)
                                                .clipShape(Capsule())
                                                .overlay(
                                                    Capsule().stroke(
                                                        selected ? .clear : Color.textTertiary.opacity(0.3)
                                                    )
                                                )
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }
                            }
                            
                            if !item.isAssigned {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12))
                                    Text("En az bir üye seçilmelidir.", comment: "Unassigned warning text")
                                        .font(.body(11, weight: .medium))
                                }
                                .foregroundStyle(Color.debt)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(14)
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: ThemeRadius.card)
                                .stroke(item.isAssigned ? Color.clear : Color.debt.opacity(0.3), lineWidth: 1.5)
                        )
                        .purpleTintedShadow(radius: 6, y: 2)
                    }
                }
                
                Button {
                    scannedItems.append(ScannedReceiptItem(name: "", amountMinor: 0))
                } label: {
                    Label("Kalem Ekle", systemImage: "plus")
                        .font(.body(14, weight: .semibold))
                        .foregroundStyle(Color.primaryTheme)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
                        .overlay(
                            RoundedRectangle(cornerRadius: ThemeRadius.button)
                                .stroke(Color.primaryTheme.opacity(0.2), lineWidth: 1)
                        )
                }
                .purpleTintedShadow(radius: 4, y: 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
    }

    private var actionPanel: some View {
        let total = scannedItems.map(\.amountMinor).reduce(0, +)
        let allAssigned = !scannedItems.isEmpty && scannedItems.allSatisfy(\.isAssigned)
        
        return VStack(spacing: 12) {
            HStack {
                Text("Toplam Tutar", comment: "Receipt total amount summary label")
                    .font(.body(14, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text(formatAmount(total, currency: currency))
                    .font(.display(20, weight: .bold))
                    .foregroundStyle(Color.primaryTheme)
            }
            .padding(.horizontal, 4)

            Button {
                guard allAssigned && total > 0 else { return }
                guard let snapshot = store.snapshot(groupID) else { return }
                
                var splits: [UUID: Int] = [:]
                let activeMembers = snapshot.activeMembers
                
                for item in scannedItems {
                    let itemSplits = computeSplits(
                        amount: item.amountMinor,
                        type: .subset,
                        memberIds: activeMembers.map(\.id),
                        subset: item.assignedMemberIds
                    )
                    for (memberId, share) in itemSplits {
                        splits[memberId, default: 0] += share
                    }
                }
                
                let desc = scannedItems.first?.name.isEmpty == false
                    ? String(localized: "Fiş: \(scannedItems.first!.name)", comment: "Default description from first parsed receipt item")
                    : String(localized: "Fiş Harcaması", comment: "Fallback default receipt description")

                onComplete(scannedItems)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Masrafa Aktar", comment: "Apply splits to parent expense button")
                }
                .font(.body(15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(allAssigned && total > 0 ? Color.primaryTheme : Color.textTertiary)
                .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
            }
            .disabled(!allAssigned || total <= 0)
            .purpleTintedShadow()
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func processScannerResult() {
        guard let text = scanner.recognizedText else { return }
        let parsed = ReceiptParser.parseReceiptText(text, currency: currency)
        
        let items = parsed.map {
            ScannedReceiptItem(name: $0.name, amountMinor: $0.amountMinor)
        }
        
        if items.isEmpty {
            feedback.error(String(localized: "Metin okunamadı, boş bir kalem listesi açılıyor.", comment: "Notification when OCR fails to find lines"))
            scannedItems = [ScannedReceiptItem(name: "", amountMinor: 0)]
        } else {
            scannedItems = items
            feedback.success(String(format: String(localized: "%d kalem başarıyla aktarıldı.", comment: "OCR success notification"), items.count))
        }
    }
}

// Camera Helper
struct CameraPicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            parent.onImageSelected(image)
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImageSelected(nil)
            parent.dismiss()
        }
    }
}
