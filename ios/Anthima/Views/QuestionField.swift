import SwiftUI
import UIKit

/// The iOS text view (the one Notes uses), so selecting a word, the loupe and
/// cut/copy/paste behave normally. Grows from one to five lines.
struct QuestionField: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    var placeholder: String
    var onSubmit: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let v = UITextView()
        v.delegate = context.coordinator
        v.font = UIFont(name: "IBMPlexSansArabic-Regular", size: 16) ?? .systemFont(ofSize: 16)
        v.textColor = UIColor(red: 0x11 / 255, green: 0x18 / 255, blue: 0x27 / 255, alpha: 1)
        v.backgroundColor = .clear
        v.textAlignment = .natural
        v.semanticContentAttribute = .forceRightToLeft
        v.isScrollEnabled = false
        v.textContainerInset = UIEdgeInsets(top: 13, left: 14, bottom: 13, right: 14)
        v.textContainer.lineFragmentPadding = 0
        v.returnKeyType = .default
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let ph = UILabel()
        ph.text = placeholder
        ph.font = v.font
        ph.textColor = UIColor(red: 0x6B / 255, green: 0x72 / 255, blue: 0x80 / 255, alpha: 1)
        ph.textAlignment = .natural
        ph.translatesAutoresizingMaskIntoConstraints = false
        ph.tag = 99
        v.addSubview(ph)
        NSLayoutConstraint.activate([
            ph.topAnchor.constraint(equalTo: v.topAnchor, constant: 13),
            ph.trailingAnchor.constraint(equalTo: v.frameLayoutGuide.trailingAnchor, constant: -14),
            ph.leadingAnchor.constraint(equalTo: v.frameLayoutGuide.leadingAnchor, constant: 14),
        ])
        return v
    }

    func updateUIView(_ v: UITextView, context: Context) {
        context.coordinator.parent = self
        if v.text != text { v.text = text }
        v.viewWithTag(99)?.isHidden = !text.isEmpty
        let lines = v.font?.lineHeight ?? 20
        let maxH = lines * 5 + 26
        let fits = v.sizeThatFits(CGSize(width: max(v.bounds.width, 100), height: .greatestFiniteMagnitude)).height
        v.isScrollEnabled = fits > maxH
        DispatchQueue.main.async {
            if focused && !v.isFirstResponder { v.becomeFirstResponder() }
            if !focused && v.isFirstResponder { v.resignFirstResponder() }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView v: UITextView, context: Context) -> CGSize? {
        let w = proposal.width ?? 300
        let lines = v.font?.lineHeight ?? 20
        let maxH = lines * 5 + 26
        let h = v.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude)).height
        return CGSize(width: w, height: min(max(h, lines + 26), maxH))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: QuestionField
        init(_ p: QuestionField) { parent = p }

        func textViewDidChange(_ v: UITextView) {
            parent.text = v.text
            v.viewWithTag(99)?.isHidden = !v.text.isEmpty
            v.invalidateIntrinsicContentSize()
        }
        func textViewDidBeginEditing(_ v: UITextView) { if !parent.focused { parent.focused = true } }
        func textViewDidEndEditing(_ v: UITextView) { if parent.focused { parent.focused = false } }
    }
}
