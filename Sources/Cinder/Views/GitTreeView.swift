import SwiftUI
import WebKit

// MARK: - Git Tree View
// Renders git log --graph output as an interactive WebKit visualization.
// Hidden "Cinder Mode": when cinderMode is ON, commit messages scatter and
// float on scroll using a text-physics JS effect (inspired by Pretext).

struct GitTreeView: View {
    let project: CinderProject
    @Environment(\.theme) private var theme

    @State private var commits: [GitCommit] = []
    @State private var isLoading = true
    @State private var cinderMode = false
    @State private var selectedCommit: GitCommit?

    private let service = GitTreeService()

    var body: some View {
        ZStack {
            theme.base.ignoresSafeArea()

            VStack(spacing: 0) {
                toolbar
                Divider().opacity(0.1)

                if isLoading {
                    loadingView
                } else if commits.isEmpty {
                    emptyView
                } else {
                    gitWebView
                }
            }
        }
        .task {
            await loadTree()
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(theme.accent)
                .font(.system(size: 13, weight: .semibold))
            Text(project.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Text("git tree")
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.4))
            Spacer()

            // Hidden Cinder Mode toggle — subtle, discoverable
            Button {
                withAnimation(.spring(duration: 0.4)) {
                    cinderMode.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: cinderMode ? "flame.fill" : "flame")
                        .font(.system(size: 11, weight: cinderMode ? .bold : .regular))
                        .foregroundStyle(cinderMode ? theme.heatBlazing : Color(white: 0.3))
                    if cinderMode {
                        Text("Cinder Mode")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.heatBlazing)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(cinderMode ? theme.heatBlazing.opacity(0.15) : Color.clear)
                        .overlay(
                            Capsule()
                                .stroke(cinderMode ? theme.heatBlazing.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .help("Cinder Mode — text physics on scroll 🔥")

            Button {
                Task { await loadTree() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.surface)
    }

    // MARK: Git Web View

    private var gitWebView: some View {
        GitWebView(
            commits: commits,
            cinderMode: cinderMode,
            theme: theme,
            onSelect: { selectedCommit = $0 }
        )
        .overlay(alignment: .bottom) {
            if let commit = selectedCommit {
                commitDetailBar(commit)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: selectedCommit?.id)
    }

    // MARK: Commit Detail Bar

    private func commitDetailBar(_ commit: GitCommit) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(commit.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(commit.id)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(theme.accent)
                    Text(commit.author)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(white: 0.4))
                    Text(commit.relativeDate)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(white: 0.35))
                }
            }
            Spacer()
            Button {
                selectedCommit = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(white: 0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.card.opacity(0.95))
        .overlay(Divider().opacity(0.1), alignment: .top)
    }

    // MARK: Loading / Empty

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(theme.accent)
            Text("Reading git log…")
                .font(.callout)
                .foregroundStyle(Color(white: 0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 28))
                .foregroundStyle(Color(white: 0.25))
            Text("No git history")
                .font(.subheadline)
                .foregroundStyle(Color(white: 0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Data

    private func loadTree() async {
        isLoading = true
        do {
            commits = try await service.fetchTree(for: project.path.path)
        } catch {
            commits = []
        }
        isLoading = false
    }
}

// MARK: - WKWebView Wrapper

struct GitWebView: NSViewRepresentable {
    let commits: [GitCommit]
    let cinderMode: Bool
    let theme: ThemeManager
    let onSelect: (GitCommit) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "commitSelected")

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.setValue(false, forKey: "drawsBackground")
        wv.allowsMagnification = true
        context.coordinator.webView = wv
        context.coordinator.onSelect = onSelect

        // Load from a temp file so the WKWebView can resolve pretext.bundle.js
        // from the same directory using a file:// base URL.
        loadFromTempFile(wv)
        return wv
    }

    private func loadFromTempFile(_ wv: WKWebView) {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cinder-tree")
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        // Copy pretext bundle alongside the HTML
        if let pretextSrc = Bundle.main.url(forResource: "pretext.bundle", withExtension: "js") {
            let pretextDst = tmpDir.appendingPathComponent("pretext.bundle.js")
            try? FileManager.default.removeItem(at: pretextDst)
            try? FileManager.default.copyItem(at: pretextSrc, to: pretextDst)
        }

        // Write the HTML file
        let htmlFile = tmpDir.appendingPathComponent("git-tree.html")
        let html = buildHTML(usePretext: FileManager.default.fileExists(
            atPath: tmpDir.appendingPathComponent("pretext.bundle.js").path
        ))
        try? html.data(using: .utf8)?.write(to: htmlFile)
        wv.loadFileURL(htmlFile, allowingReadAccessTo: tmpDir)
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        let js = """
        if (window.cinderTree) {
            window.cinderTree.updateMode(\(cinderMode ? "true" : "false"));
        }
        """
        wv.evaluateJavaScript(js, completionHandler: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var onSelect: ((GitCommit) -> Void)?

        func userContentController(
            _ controller: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            // Handle commit selection messages from JS
        }
    }

    // MARK: - HTML Generation

    private func buildHTML(usePretext: Bool = false) -> String {
        let commitJSON = commitsToJSON()
        let accentHex  = theme.current.accent1.hexString
        let baseHex    = theme.current.base.hexString
        let surfaceHex = theme.current.surface.hexString
        let cardHex    = theme.current.card.hexString
        let pretextTag = usePretext ? "<script src=\"pretext.bundle.js\"></script>" : ""

        return """
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
\(pretextTag)
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body {
    background: \(baseHex);
    color: #fff;
    font-family: 'SF Mono', 'Menlo', monospace;
    font-size: 12px;
    overflow-x: hidden;
  }
  #tree {
    padding: 16px 0;
  }
  .row {
    display: flex;
    align-items: center;
    padding: 2px 16px;
    min-height: 28px;
    transition: background 0.15s;
    cursor: default;
  }
  .row:hover { background: \(surfaceHex); }
  .row.selected { background: \(cardHex); }

  .graph {
    font-family: 'SF Mono', monospace;
    font-size: 11px;
    color: \(accentHex);
    white-space: pre;
    min-width: 140px;
    opacity: 0.7;
  }
  .hash {
    font-family: 'SF Mono', monospace;
    font-size: 10px;
    color: \(accentHex);
    min-width: 56px;
    opacity: 0.8;
  }
  .message {
    flex: 1;
    font-family: -apple-system, sans-serif;
    font-size: 12px;
    color: #e0e0e0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    padding: 0 12px;
    transition: transform 0.05s, color 0.3s;
  }
  .ref-badge {
    display: inline-block;
    font-size: 9px;
    font-weight: 600;
    padding: 1px 6px;
    border-radius: 8px;
    margin-right: 4px;
    background: \(accentHex)26;
    color: \(accentHex);
    border: 1px solid \(accentHex)44;
  }
  .ref-badge.head { background: #22cc6644; color: #44ee88; border-color: #22cc6666; }
  .ref-badge.remote { background: #4488ff22; color: #88aaff; border-color: #4488ff44; }
  .ref-badge.tag { background: #ffaa2222; color: #ffcc55; border-color: #ffaa2244; }
  .meta {
    font-size: 10px;
    color: rgba(255,255,255,0.3);
    min-width: 120px;
    text-align: right;
    padding-right: 8px;
  }
  .author {
    font-size: 10px;
    color: rgba(255,255,255,0.25);
    min-width: 80px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* Cinder Mode — text physics */
  .cinder-mode .message {
    will-change: transform;
    cursor: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='20' height='20'%3E%3Ctext y='16' font-size='16'%3E🔥%3C/text%3E%3C/svg%3E") 10 10, auto;
  }
  .cinder-mode .row:hover .message {
    color: \(accentHex);
  }

  /* Scrollbar */
  ::-webkit-scrollbar { width: 6px; }
  ::-webkit-scrollbar-track { background: transparent; }
  ::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 3px; }
</style>
</head>
<body>
<div id="tree"></div>

<script>
const commits = \(commitJSON);
const accent  = '\(accentHex)';

// ── Render ──────────────────────────────────────────────────────────────────

function renderRow(c, i) {
  const row = document.createElement('div');
  row.className = 'row';
  row.dataset.index = i;

  // Graph column
  const graph = document.createElement('span');
  graph.className = 'graph';
  graph.textContent = c.graphLine || '* ';
  row.appendChild(graph);

  // Hash
  const hash = document.createElement('span');
  hash.className = 'hash';
  hash.textContent = c.id;
  row.appendChild(hash);

  // Refs
  const refWrap = document.createElement('span');
  refWrap.style.minWidth = '0';
  c.refs.forEach(r => {
    const b = document.createElement('span');
    b.textContent = r.replace('HEAD -> ', '');
    if (r.startsWith('HEAD')) b.className = 'ref-badge head';
    else if (r.startsWith('origin/') || r.startsWith('upstream/')) b.className = 'ref-badge remote';
    else if (r.startsWith('tag:')) b.className = 'ref-badge tag';
    else b.className = 'ref-badge';
    refWrap.appendChild(b);
  });
  row.appendChild(refWrap);

  // Message — each word wrapped for Cinder Mode scatter
  const msg = document.createElement('span');
  msg.className = 'message';
  msg.dataset.original = c.message;
  c.message.split(' ').forEach((word, wi) => {
    const span = document.createElement('span');
    span.className = 'word';
    span.textContent = word + ' ';
    span.style.display = 'inline-block';
    span.style.transition = 'transform ' + (0.3 + wi * 0.03) + 's cubic-bezier(.22,.68,0,1.2)';
    msg.appendChild(span);
  });
  row.appendChild(msg);

  // Meta (date)
  const meta = document.createElement('span');
  meta.className = 'meta';
  meta.textContent = c.relativeDate;
  row.appendChild(meta);

  // Author
  const auth = document.createElement('span');
  auth.className = 'author';
  auth.textContent = c.author.split(' ')[0];
  row.appendChild(auth);

  return row;
}

function render() {
  const tree = document.getElementById('tree');
  tree.innerHTML = '';
  commits.forEach((c, i) => tree.appendChild(renderRow(c, i)));
}

// ── Cinder Mode — word physics on scroll ────────────────────────────────────
// Uses @chenglou/pretext for accurate word measurement when available,
// falling back to element offsets. Words drift on scroll, spring back at rest.

let cinderMode = false;
let lastScroll = 0;
let velocity = 0;
let scattered = false;

// Pre-measure word widths with Pretext if available
// Pretext.prepareWithSegments gives us segments with accurate widths per segment,
// avoiding DOM layout reflow for per-word sizing.
function measureWords(msgEl) {
  const words = msgEl.querySelectorAll('.word');
  if (typeof Pretext !== 'undefined' && Pretext.prepareWithSegments) {
    const text = msgEl.dataset.original || '';
    const font = '12px -apple-system, sans-serif';
    try {
      const prepared = Pretext.prepareWithSegments(text, font);
      const { lines } = Pretext.layoutWithLines(prepared, msgEl.offsetWidth || 400, 20);
      if (lines && lines.length > 0) {
        // Assign measured widths to word spans for proportional scatter
        let wi = 0;
        lines.forEach(line => {
          // each line.text is a slice; map back to word spans proportionally
          const lineWords = line.text.trim().split(/\\s+/);
          lineWords.forEach(lw => {
            if (words[wi]) {
              words[wi].dataset.measuredWidth = String(line.width / lineWords.length);
              wi++;
            }
          });
        });
      }
    } catch (e) {
      // Pretext not fully loaded yet — fall back to offset widths
    }
  }
  return words;
}

function scatter(velo) {
  if (!cinderMode) return;
  const words = document.querySelectorAll('.word');
  words.forEach((w, i) => {
    // Use Pretext-measured width for proportional scatter if available
    const measuredW = parseFloat(w.dataset.measuredWidth || '0');
    const scaleBoost = measuredW > 0 ? (measuredW / 60) : 1; // wider words scatter further
    const drift = (Math.random() - 0.5) * Math.abs(velo) * 1.2 * scaleBoost;
    const rise  = (Math.random() - 0.5) * Math.abs(velo) * 0.8;
    const rot   = (Math.random() - 0.5) * Math.min(Math.abs(velo) * 0.5, 12);
    w.style.transform = 'translate(' + drift + 'px, ' + rise + 'px) rotate(' + rot + 'deg)';
    w.style.opacity = Math.max(0.3, 1 - Math.abs(velo) / 120);
  });
  scattered = true;
}

// Pre-measure on load when Pretext is ready
function premeasureAll() {
  document.querySelectorAll('.message').forEach(m => measureWords(m));
}

function settle() {
  if (!scattered) return;
  const words = document.querySelectorAll('.word');
  words.forEach(w => {
    w.style.transform = 'translate(0, 0) rotate(0deg)';
    w.style.opacity = '1';
  });
  scattered = false;
}

let settleTimeout;
window.addEventListener('scroll', () => {
  const y = window.scrollY;
  velocity = y - lastScroll;
  lastScroll = y;
  if (cinderMode && Math.abs(velocity) > 2) scatter(velocity);
  clearTimeout(settleTimeout);
  settleTimeout = setTimeout(settle, 200);
}, { passive: true });

// Hover scatter — subtle word drift on hover in Cinder Mode
document.getElementById('tree').addEventListener('mousemove', (e) => {
  if (!cinderMode) return;
  const row = e.target.closest('.row');
  if (!row) return;
  const words = row.querySelectorAll('.word');
  const rx = (e.offsetX / row.offsetWidth - 0.5);
  const ry = (e.offsetY / row.offsetHeight - 0.5);
  words.forEach((w, i) => {
    const mag = (i % 2 === 0 ? 1 : -1);
    w.style.transform = 'translate(' + (rx * 8 * mag) + 'px, ' + (ry * 4) + 'px)';
  });
});
document.getElementById('tree').addEventListener('mouseleave', settle);

// ── Public API ──────────────────────────────────────────────────────────────

window.cinderTree = {
  updateMode(enabled) {
    cinderMode = enabled;
    document.body.classList.toggle('cinder-mode', enabled);
    if (!enabled) settle();
  }
};

// ── Init ────────────────────────────────────────────────────────────────────
render();
// Measure words after render so Pretext can use accurate element widths
requestAnimationFrame(premeasureAll);
</script>
</body>
</html>
"""
    }

    private func commitsToJSON() -> String {
        let mapped = commits.map { c in
            let refs = c.refs.map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }.joined(separator: ",")
            return """
            {"id":"\(c.id)","message":"\(c.message.jsonEscaped)","author":"\(c.author.jsonEscaped)","date":"\(c.date)","relativeDate":"\(c.relativeDate.jsonEscaped)","refs":[\(refs)],"graphLine":"\(c.graphLine.jsonEscaped)","isMerge":\(c.isMerge)}
            """
        }
        return "[\(mapped.joined(separator: ",\n"))]"
    }
}

private extension String {
    var jsonEscaped: String {
        self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}

// MARK: - Color hex helper

extension Color {
    var hexString: String {
        guard let components = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components,
              components.count >= 3 else { return "#888888" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
