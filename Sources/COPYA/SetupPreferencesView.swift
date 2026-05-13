import AppKit
import COPYACore
import SwiftUI

final class SetupPreferencesWindowController: NSWindowController {
    static let shared = SetupPreferencesWindowController()

    private init() {
        let rootView = SetupPreferencesView(monitor: BackupMonitor.shared)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "COPYA Setup & Preferences"
        window.setContentSize(NSSize(width: 760, height: 720))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        guard let window else {
            return
        }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SetupPreferencesView: View {
    @ObservedObject var monitor: BackupMonitor

    @State private var draft: RuntimeConfig
    @State private var denySSIDsText: String
    @State private var cloudRootsText: String
    @State private var password = ""
    @State private var b2Mode = KopiaRepositoryMode.connect
    @State private var b2Bucket = ""
    @State private var b2Region = ""
    @State private var b2Endpoint = ""
    @State private var b2Prefix = ""
    @State private var b2KeyID = ""
    @State private var b2ApplicationKey = ""
    @State private var filesystemMode = KopiaRepositoryMode.connect
    @State private var filesystemPath = ""
    @State private var message: String?

    init(monitor: BackupMonitor) {
        self.monitor = monitor
        let config = Config.runtime
        _draft = State(initialValue: config)
        _denySSIDsText = State(initialValue: config.deny_ssids.joined(separator: "\n"))
        _cloudRootsText = State(initialValue: config.cloud_materialization_roots.joined(separator: "\n"))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                preferencesSection
                passwordSection
                repositorySection
                permissionsSection
                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 720, minHeight: 680)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COPYA")
                .font(.title.bold())
            Text(monitor.setupGate.summary)
                .foregroundStyle(monitor.setupGate.complete ? .green : .orange)
            if !monitor.setupGate.complete {
                ForEach(monitor.setupGate.blockers, id: \.rawValue) { blocker in
                    Text("• \(blocker.userText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var preferencesSection: some View {
        GroupBox("Backup Preferences") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Backup source")
                    HStack {
                        TextField("Backup source", text: $draft.backup_source)
                        Button("Choose...") {
                            chooseDirectory { draft.backup_source = $0 }
                        }
                    }
                }
                GridRow {
                    Text("Interval")
                    Stepper(
                        "\(max(1, draft.run_interval_seconds / 3600)) hours",
                        value: Binding(
                            get: { max(1, draft.run_interval_seconds / 3600) },
                            set: { draft.run_interval_seconds = max(1, $0) * 3600 }
                        ),
                        in: 1...168
                    )
                }
                GridRow {
                    Text("Denylisted Wi-Fi")
                    TextEditor(text: $denySSIDsText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 72)
                }
                GridRow {
                    Text("Cloud prep")
                    Toggle("Hydrate iCloud/FileProvider files before backup", isOn: $draft.cloud_materialization_enabled)
                }
                GridRow {
                    Text("Cloud roots")
                    TextEditor(text: $cloudRootsText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 92)
                }
                GridRow {
                    Text("Limited backup")
                    Toggle("I understand missing Full Disk Access can omit protected local data", isOn: $draft.limited_backup_acknowledged)
                }
                GridRow {
                    Text("")
                    Button("Save Preferences") {
                        savePreferences()
                    }
                    .disabled(!monitor.canSavePreferences)
                }
            }
            .padding(10)
        }
    }

    private var passwordSection: some View {
        GroupBox("Kopia Password") {
            VStack(alignment: .leading, spacing: 10) {
                Text(KeychainPasswordStore.hasPassword() ? "Password is stored in Keychain." : "Password is not stored in Keychain.")
                    .foregroundStyle(.secondary)
                SecureField("Kopia repository password", text: $password)
                Button("Store Password in Keychain") {
                    do {
                        try monitor.storeKeychainPasswordFromPreferences(password)
                        password = ""
                        message = "Password stored in Keychain."
                    } catch {
                        message = error.localizedDescription
                    }
                }
            }
            .padding(10)
        }
    }

    private var repositorySection: some View {
        GroupBox("Repository") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Status: \(monitor.repositoryStatus.state.rawValue)")
                    if let detail = monitor.repositoryStatus.detail {
                        Text(detail)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Check Repository") {
                        monitor.refreshRepositoryStatus()
                    }
                    .disabled(!monitor.canSavePreferences)
                }

                Divider()

                Text("Backblaze B2 (Kopia S3 provider)")
                    .font(.headline)
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("Mode")
                        Picker("Mode", selection: $b2Mode) {
                            Text("Connect").tag(KopiaRepositoryMode.connect)
                            Text("Create").tag(KopiaRepositoryMode.create)
                        }
                        .pickerStyle(.segmented)
                    }
                    GridRow { Text("Bucket"); TextField("bucket-name", text: $b2Bucket) }
                    GridRow { Text("Region"); TextField("us-west-004", text: $b2Region) }
                    GridRow { Text("Endpoint"); TextField("Optional, s3.<region>.backblazeb2.com", text: $b2Endpoint) }
                    GridRow { Text("Prefix"); TextField("Optional repository prefix", text: $b2Prefix) }
                    GridRow { Text("Key ID"); TextField("Backblaze application key ID", text: $b2KeyID) }
                    GridRow { Text("Application key"); SecureField("Backblaze application key", text: $b2ApplicationKey) }
                    GridRow {
                        Text("")
                        Button("\(b2Mode == .connect ? "Connect" : "Create") B2 Repository") {
                            monitor.setupBackblazeRepository(
                                mode: b2Mode,
                                bucket: b2Bucket,
                                endpoint: b2Endpoint,
                                region: b2Region,
                                prefix: b2Prefix,
                                accessKeyID: b2KeyID,
                                applicationKey: b2ApplicationKey
                            )
                        }
                        .disabled(!monitor.canSavePreferences)
                    }
                }

                Divider()

                Text("Local Filesystem Repository")
                    .font(.headline)
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("Mode")
                        Picker("Mode", selection: $filesystemMode) {
                            Text("Connect").tag(KopiaRepositoryMode.connect)
                            Text("Create").tag(KopiaRepositoryMode.create)
                        }
                        .pickerStyle(.segmented)
                    }
                    GridRow {
                        Text("Path")
                        HStack {
                            TextField("Repository directory", text: $filesystemPath)
                            Button("Choose...") {
                                chooseDirectory { filesystemPath = $0 }
                            }
                        }
                    }
                    GridRow {
                        Text("")
                        Button("\(filesystemMode == .connect ? "Connect" : "Create") Filesystem Repository") {
                            monitor.setupFilesystemRepository(mode: filesystemMode, path: filesystemPath)
                        }
                        .disabled(!monitor.canSavePreferences)
                    }
                }
            }
            .padding(10)
        }
    }

    private var permissionsSection: some View {
        GroupBox("Permissions & Login") {
            HStack {
                Button("Grant Wi-Fi Permission") {
                    monitor.requestLocationPermission()
                }
                Button("Open Full Disk Access") {
                    monitor.openFullDiskAccessSettings()
                }
                Button("Enable at Login") {
                    do {
                        try LaunchAgentManager.service.register()
                        message = "Login item enabled."
                    } catch {
                        message = error.localizedDescription
                    }
                }
                Button("Disable Login Agent") {
                    do {
                        try LaunchAgentManager.service.unregister()
                        message = "Login item disabled."
                    } catch {
                        message = error.localizedDescription
                    }
                }
                Button("Open Login Items") {
                    LaunchAgentManager.openSettings()
                }
            }
            .padding(10)
        }
    }

    private func savePreferences() {
        draft.deny_ssids = lines(from: denySSIDsText)
        draft.cloud_materialization_roots = lines(from: cloudRootsText)
        draft.password_source = "keychain"
        draft.password_env_var = "KOPIA_PASSWORD"
        draft.password_command = []
        draft.kopia_password_ref = ""
        do {
            try monitor.saveRuntimeConfig(draft)
            message = "Preferences saved."
        } catch {
            message = error.localizedDescription
        }
    }

    private func lines(from text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func chooseDirectory(_ apply: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            apply(url.path)
        }
    }
}
