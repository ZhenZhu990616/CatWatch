import AppKit
import Foundation

/// 把模型回答里的 Markdown 渲染成富文本：
/// - 围栏代码块（``` ... ```）：先按行扫出，原样保留换行与缩进，等宽字体渲染。
///   不能交给 inline-only 解析器——它会把围栏当成行内代码 span，
///   而 CommonMark 规定行内代码里的换行折叠为空格，整段代码会被压成一行。
/// - 其余文本：行内语法（**粗体**、*斜体*、`代码`）解析，块级标记保持原样字符。
/// 解析失败时整体回退纯文本。
enum MarkdownRenderer {
    static func render(_ text: String, font: NSFont, color: NSColor) -> NSAttributedString {
        guard !text.isEmpty else {
            return NSAttributedString(string: "", attributes: [.font: font, .foregroundColor: color])
        }

        let output = NSMutableAttributedString()
        for segment in splitFencedBlocks(text) {
            switch segment {
            case .code(let body):
                output.append(NSAttributedString(string: body, attributes: codeAttributes(font: font, color: color)))
            case .text(let body):
                output.append(renderInline(body, font: font, color: color))
            }
        }
        return output
    }

    private enum Segment {
        case text(String)
        case code(String)
    }

    /// 按行扫描围栏代码块：``` 或 ```lang 开栏、``` 收栏（围栏行本身丢弃）。
    /// 未闭合的围栏（流式输出中途）把剩余部分都当代码，避免渲染来回跳变。
    private static func splitFencedBlocks(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        var currentText: [Substring] = []
        var currentCode: [Substring] = []
        var inFence = false

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inFence {
                    segments.append(.code(currentCode.joined(separator: "\n") + "\n"))
                    currentCode = []
                    inFence = false
                } else {
                    if !currentText.isEmpty {
                        segments.append(.text(currentText.joined(separator: "\n") + "\n"))
                        currentText = []
                    }
                    inFence = true
                }
                continue
            }

            if inFence {
                currentCode.append(line)
            } else {
                currentText.append(line)
            }
        }

        if !currentText.isEmpty {
            segments.append(.text(currentText.joined(separator: "\n")))
        }
        if !currentCode.isEmpty || inFence {
            segments.append(.code(currentCode.joined(separator: "\n")))
        }
        return segments
    }

    private static func codeAttributes(font: NSFont, color: NSColor) -> [NSAttributedString.Key: Any] {
        // 不加底色：等宽字体已足够区分代码，底色框在低透明度隐身配置下会露馅。
        [
            .font: NSFont.monospacedSystemFont(ofSize: font.pointSize * 0.94, weight: .regular),
            .foregroundColor: color
        ]
    }

    private static func renderInline(_ text: String, font: NSFont, color: NSColor) -> NSAttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible

        guard let parsed = try? AttributedString(markdown: text, options: options) else {
            return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        }

        let output = NSMutableAttributedString()
        for run in parsed.runs {
            let substring = String(parsed[run.range].characters)
            var runFont = font
            var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color]

            if let intent = run.inlinePresentationIntent {
                if intent.contains(.code) {
                    // 行内代码仅用等宽字体区分，同样不加底色。
                    runFont = .monospacedSystemFont(ofSize: font.pointSize * 0.94, weight: .regular)
                }
                if intent.contains(.stronglyEmphasized) {
                    runFont = NSFontManager.shared.convert(runFont, toHaveTrait: .boldFontMask)
                }
                if intent.contains(.emphasized) {
                    runFont = NSFontManager.shared.convert(runFont, toHaveTrait: .italicFontMask)
                }
            }

            attributes[.font] = runFont
            output.append(NSAttributedString(string: substring, attributes: attributes))
        }

        return output
    }
}
