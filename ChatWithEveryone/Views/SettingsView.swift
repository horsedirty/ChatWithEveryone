import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss

    @State private var editingProvider: APIProvider?
    @State private var newProviderName = ""
    @State private var newProviderType: APIProviderType = .deepseek
    @State private var newProviderBaseURL = ""
    @State private var newProviderAPIKey = ""
    @State private var newProviderModel = ""
    @State private var newImageGenBaseURL = ""
    @State private var newCustomModel = ""
    @State private var showingAddSheet = false

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("API 配置")
                    .font(.songtiTimes(size: 13, weight: .semibold))
                Spacer()
                Button("完成") { dismiss() }
            }
            .padding()

            Divider()

            List {
                Section("已配置的提供商") {
                    ForEach(viewModel.providers) { provider in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(provider.name)
                                    .font(.songtiTimes(size: 13))
                                Text("\(provider.providerType.rawValue) - \(provider.model)")
                                    .font(.songtiTimes(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if provider.isEnabled {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingProvider = provider
                            newProviderName = provider.name
                            newProviderType = provider.providerType
                            newProviderBaseURL = provider.baseURL
                            newProviderAPIKey = provider.apiKey
                            newProviderModel = provider.model
                            newImageGenBaseURL = provider.imageGenerationBaseURL ?? ""
                            showingAddSheet = true
                        }
                    }
                    .onDelete { indexSet in
                        viewModel.providers.remove(atOffsets: indexSet)
                        viewModel.save()
                    }
                }

                Section("快速添加") {
                    ForEach(APIProviderType.allCases, id: \.rawValue) { type in
                        Button {
                            addQuickProvider(type)
                        } label: {
                            HStack {
                                Text(type.rawValue)
                                Spacer()
                                Text(type.defaultModel)
                                    .font(.songtiTimes(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("关于") {
                    HStack {
                        Text("当前版本")
                        Spacer()
                        Text(versionString)
                            .foregroundColor(.secondary)
                    }
                    Button("检查更新…") {
                        dismiss()
                        NotificationCenter.default.post(name: .didRequestUpdateCheck, object: nil)
                    }
                }
            }

            Divider()

            HStack {
                Button {
                    newProviderName = ""
                    newProviderType = .deepseek
                    newProviderBaseURL = ""
                    newProviderAPIKey = ""
                    newProviderModel = ""
                    newImageGenBaseURL = ""
                    editingProvider = nil
                    showingAddSheet = true
                } label: {
                    Label("添加自定义提供商", systemImage: "plus")
                }
                Spacer()
            }
            .padding()
        }
        .frame(width: 520, height: 500)
        .sheet(isPresented: $showingAddSheet) {
            providerEditSheet
        }
    }

    var providerEditSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text(editingProvider == nil ? "添加提供商" : "编辑提供商")
                    .font(.songtiTimes(size: 13, weight: .semibold))
                Spacer()
                Button("取消") {
                    showingAddSheet = false
                }
            }
            .padding()

            Divider()

            ScrollView {
                Form {
                    TextField("名称", text: $newProviderName)
                    Picker("类型", selection: $newProviderType) {
                        ForEach(APIProviderType.allCases, id: \.rawValue) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .onChange(of: newProviderType) { _, newType in
                        if newProviderBaseURL.isEmpty || newProviderBaseURL == APIProviderType.deepseek.defaultBaseURL {
                            newProviderBaseURL = newType.defaultBaseURL
                        }
                        if newProviderModel.isEmpty || newProviderModel == "deepseek-v4-flash" {
                            newProviderModel = newType.defaultModel
                        }
                    }
                    TextField("Base URL", text: $newProviderBaseURL)
                    SecureField("API Key", text: $newProviderAPIKey)
                    TextField("默认模型名称", text: $newProviderModel)
                    TextField("图片生成地址", text: $newImageGenBaseURL)

                    if let existing = editingProvider {
                        Section("自定义模型") {
                            ForEach(existing.customModels, id: \.self) { model in
                                HStack {
                                    Text(model)
                                        .font(.songtiTimes(size: 10))
                                    Spacer()
                                    Button {
                                        viewModel.removeCustomModel(from: existing.id, model: model)
                                        editingProvider = viewModel.providers.first(where: { $0.id == existing.id })
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            HStack {
                                TextField("添加自定义模型", text: $newCustomModel)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.songtiTimes(size: 10))
                                Button {
                                    viewModel.addCustomModel(to: existing.id, model: newCustomModel)
                                    editingProvider = viewModel.providers.first(where: { $0.id == existing.id })
                                    newCustomModel = ""
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                                .disabled(newCustomModel.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()

            HStack {
                if let existing = editingProvider {
                    Button("删除", role: .destructive) {
                        viewModel.providers.removeAll(where: { $0.id == existing.id })
                        viewModel.save()
                        showingAddSheet = false
                    }
                }
                Spacer()
                Button("保存") {
                    saveProvider()
                    showingAddSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newProviderName.isEmpty || newProviderBaseURL.isEmpty || newProviderAPIKey.isEmpty)
            }
            .padding()
        }
        .frame(width: 480, height: 500)
    }

    private func saveProvider() {
        let provider = APIProvider(
            id: editingProvider?.id ?? UUID(),
            name: newProviderName,
            providerType: newProviderType,
            baseURL: newProviderBaseURL,
            apiKey: newProviderAPIKey,
            model: newProviderModel,
            customModels: editingProvider?.customModels ?? [],
            imageGenerationBaseURL: newImageGenBaseURL.trimmingCharacters(in: .whitespaces).isEmpty ? nil : newImageGenBaseURL
        )

        if let existing = editingProvider,
           let idx = viewModel.providers.firstIndex(where: { $0.id == existing.id }) {
            viewModel.providers[idx] = provider
        } else {
            viewModel.providers.append(provider)
        }
        viewModel.save()
    }

    private func addQuickProvider(_ type: APIProviderType) {
        let provider = APIProvider.default(for: type)
        newProviderName = provider.name
        newProviderType = provider.providerType
        newProviderBaseURL = provider.baseURL
        newProviderAPIKey = provider.apiKey
        newProviderModel = provider.model
        newImageGenBaseURL = provider.imageGenerationBaseURL ?? ""
        editingProvider = nil
        showingAddSheet = true
    }
}
