import UIKit
import Vision
import PDFKit

/// قراءة الصور وملفات PDF على الجهاز بمحرك Apple (Vision). لا يُرسل شيء خارج الجهاز.
enum OCR {
    struct Result {
        let text: String
        let confidence: Double   // 0…100
        let ocr: Bool            // قراءة ضوئية أم نص رقمي من PDF
    }

    /// هل يدعم هذا الجهاز قراءة العربية؟
    static var arabicSupported: Bool {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        let langs = (try? req.supportedRecognitionLanguages()) ?? []
        return langs.contains { $0.lowercased().hasPrefix("ar") }
    }

    static func read(image: UIImage) async -> Result {
        guard let cg = prepared(image) else { return Result(text: "", confidence: 0, ocr: true) }
        return await recognize(cg)
    }

    static func read(pdf url: URL) async -> Result {
        guard let doc = PDFDocument(url: url) else { return Result(text: "", confidence: 0, ocr: false) }
        var parts: [String] = []
        var confs: [Double] = []
        var usedOCR = false
        let n = min(doc.pageCount, 15)
        for i in 0..<n {
            guard let page = doc.page(at: i) else { continue }
            let txt = (page.string ?? "").precomposedStringWithCompatibilityMapping
            if arabicScore(txt) >= 3 {
                parts.append(txt)
            } else {
                let bounds = page.bounds(for: .mediaBox)
                let scale: CGFloat = 2.2
                let img = page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
                if let cg = img.cgImage {
                    let r = await recognize(cg)
                    parts.append(r.text); confs.append(r.confidence); usedOCR = true
                }
            }
        }
        var text = parts.joined(separator: "\n\n— صفحة —\n\n")
        if doc.pageCount > n { text += "\n\n(قُرئت أول \(n) صفحة من \(doc.pageCount))" }
        let conf = confs.isEmpty ? 100 : confs.reduce(0, +) / Double(confs.count)
        return Result(text: text, confidence: conf, ocr: usedOCR)
    }

    private static func arabicScore(_ t: String) -> Int {
        let words = ["في", "من", "على", "رقم", "إلى", "عقد", "تاريخ", "المملكة", "السعودية"]
        let tokens = t.split(whereSeparator: { $0.isWhitespace || $0 == "،" || $0 == ":" || $0 == "." })
        return tokens.filter { words.contains(String($0)) }.count
    }

    /// يكبّر الصور الصغيرة لتحسين القراءة.
    private static func prepared(_ image: UIImage) -> CGImage? {
        let w = image.size.width * image.scale
        var scale: CGFloat = 1
        if w < 1600 { scale = min(3, 1800 / max(w, 1)) }
        if w * scale > 3200 { scale = 3200 / w }
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let out = UIGraphicsImageRenderer(size: target, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return out.cgImage
    }

    private static func recognize(_ cg: CGImage) async -> Result {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let req = VNRecognizeTextRequest()
                req.recognitionLevel = .accurate
                req.usesLanguageCorrection = true
                let supported = (try? req.supportedRecognitionLanguages()) ?? []
                let wanted = supported.filter { $0.lowercased().hasPrefix("ar") } + supported.filter { $0.lowercased().hasPrefix("en") }
                if !wanted.isEmpty { req.recognitionLanguages = wanted }
                do {
                    try VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
                } catch {
                    cont.resume(returning: Result(text: "", confidence: 0, ocr: true))
                    return
                }
                let obs: [VNRecognizedTextObservation] = req.results ?? []
                // ترتيب الأسطر من الأعلى للأسفل، وفي السطر الواحد من اليمين لليسار
                var lines: [(CGRect, String, Float)] = []
                for o in obs {
                    if let c = o.topCandidates(1).first { lines.append((o.boundingBox, c.string, c.confidence)) }
                }
                let sorted = lines.sorted { a, b in
                    let ay = (a.0.midY * 50).rounded(), by = (b.0.midY * 50).rounded()
                    if ay != by { return ay > by }
                    return a.0.minX > b.0.minX
                }
                var rows: [String] = []
                var lastY: CGFloat? = nil
                for l in sorted {
                    let y = (l.0.midY * 50).rounded()
                    if let ly = lastY, ly == y, !rows.isEmpty { rows[rows.count - 1] += " " + l.1 }
                    else { rows.append(l.1) }
                    lastY = y
                }
                let total = lines.reduce(Float(0)) { $0 + $1.2 }
                let conf = lines.isEmpty ? 0 : Double(total) / Double(lines.count) * 100
                cont.resume(returning: Result(text: rows.joined(separator: "\n"), confidence: conf, ocr: true))
            }
        }
    }
}
