import SwiftUI
import Network

struct APIStatusView: View {
    let server: CinderAPIServer

    @State private var showEndpoints  = false
    @State private var showKey        = false
    @State private var copiedURL: String? = nil

    private var localURL: String     { "http://localhost:\(CinderAPIServer.port)" }
    private var tailscaleURL: String { "http://100.71.141.45:\(CinderAPIServer.port)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().background(Color.cinderBorder)

            VStack(alignment: .leading, spacing: 8) {
                // Status row
                HStack(spacing: 6) {
                    Circle()
                        .fill(server.isRunning ? Color.reigniteGreen : Color.archiveGrey)
                        .frame(width: 7, height: 7)
                        .shadow(color: server.isRunning ? Color.reigniteGreen.opacity(0.6) : .clear, radius: 4)

                    Text(server.isRunning ? "API Running" : "API Stopped")
                        .font(.caption.bold())
                        .foregroundStyle(server.isRunning ? .cinderPrimary : .cinderMuted)

                    Spacer()

                    Button {
                        showEndpoints.toggle()
                    } label: {
                        Image(systemName: showEndpoints ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.cinderMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showEndpoints ? "Hide endpoints" : "Show endpoints")
                }

                // Port + URLs
                if server.isRunning {
                    VStack(alignment: .leading, spacing: 4) {
                        urlRow("Local", localURL)
                        urlRow("Tailscale", tailscaleURL)
                    }

                    // API Key row
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.heatWarm)
                        if showKey {
                            Text(server.apiKey)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.cinderSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("••••••••••••••••••••")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.cinderMuted)
                        }
                        Spacer()
                        // Toggle visibility
                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .font(.system(size: 9))
                                .foregroundStyle(.cinderMuted)
                        }
                        .buttonStyle(.plain)
                        // Copy key
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(server.apiKey, forType: .string)
                            withAnimation { copiedURL = "key" }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { copiedURL = nil }
                            }
                        } label: {
                            Image(systemName: copiedURL == "key" ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundStyle(copiedURL == "key" ? Color.reigniteGreen : .cinderMuted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Copy API key")
                        // Regenerate
                        Button {
                            server.regenerateAPIKey()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9))
                                .foregroundStyle(.cinderMuted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Regenerate API key")
                        .help("Generate a new API key")
                    }
                }

                // Last request
                if server.isRunning && !server.lastRequest.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.cinderMuted)
                        Text(server.lastRequest)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.cinderMuted)
                            .lineLimit(1)
                        Spacer()
                        Text("\(server.requestCount)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.cinderMuted)
                    }
                }

                // Endpoints reference
                if showEndpoints {
                    endpointsView
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .overlay(
            Group {
                if let url = copiedURL {
                    Text("Copied!")
                        .font(.caption.bold())
                        .foregroundStyle(.reigniteGreen)
                        .padding(6)
                        .background(Color.cinderCard)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .transition(.opacity.combined(with: .scale))
                }
            },
            alignment: .bottom
        )
    }

    // MARK: - URL Row

    private func urlRow(_ label: String, _ url: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.cinderMuted)
                .frame(width: 54, alignment: .leading)

            Text(":\(CinderAPIServer.port)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.heatWarm.opacity(0.8))

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
                withAnimation(.easeOut(duration: 0.2)) { copiedURL = url }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { copiedURL = nil }
                }
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundStyle(.cinderMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy \(label) URL")
        }
    }

    // MARK: - Endpoints List

    private var endpointsView: some View {
        VStack(alignment: .leading, spacing: 3) {
            endpointRow("GET",  "/api/health")
            endpointRow("GET",  "/api/stats")
            endpointRow("GET",  "/api/digest")
            endpointRow("GET",  "/api/projects")
            endpointRow("GET",  "/api/projects/hot")
            endpointRow("GET",  "/api/projects/cold")
            endpointRow("GET",  "/api/projects/random")
            endpointRow("GET",  "/api/projects/{name}")
            endpointRow("POST", "/api/projects/{name}/reignite")
            endpointRow("POST", "/api/projects/{name}/snooze")
            endpointRow("POST", "/api/projects/{name}/archive")
            endpointRow("POST", "/api/refresh")
            endpointRow("GET",  "/api/skills")
            endpointRow("POST", "/api/skills/launch")
        }
        .padding(.top, 4)
    }

    private func endpointRow(_ method: String, _ path: String) -> some View {
        HStack(spacing: 5) {
            Text(method)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(method == "GET" ? Color.snoozeBlue : Color.heatWarm)
                .frame(width: 26, alignment: .leading)
            Text(path)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.cinderSecondary)
                .lineLimit(1)
        }
    }
}
