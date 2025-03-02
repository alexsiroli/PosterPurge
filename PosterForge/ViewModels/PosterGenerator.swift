// ========================================
// File: PosterGenerator.swift
// ========================================
//
// Traduzione fedele del codice Python "MoviePosters.ipynb" in Swift.
// Genera layout 'traditional' o 'modern'.
//
// Se vuoi personalizzare la grafica, modifica i parametri geometrici.
//
// Per la persistenza delle immagini, si demanda al LibraryViewModel.
//
// ========================================

import UIKit
import CoreGraphics
import CoreImage

class PosterGenerator {
    static let shared = PosterGenerator()

    // Dimensioni generali (iPhone 15)
    private let iphoneWidth: CGFloat = 1179
    private let iphoneHeight: CGFloat = 2556

    // --- Layout Tradizionale ---
    private let tradQuadX: CGFloat = 190
    private let tradQuadY: CGFloat = 700
    private let tradQuadW: CGFloat = 800
    private let tradQuadH: CGFloat = 1400

    private let tradPosterW: CGFloat = 682
    private let tradPosterH: CGFloat = 1023
    private let tradPosterX: CGFloat = 250
    private let tradPosterY: CGFloat = 960

    private let tradTitlePoint = CGPoint(x: 247, y: 749)
    private let tradYearPoint = CGPoint(x: 893, y: 749)

    private let tradStarsStartX: CGFloat = 300
    private let tradStarsY: CGFloat = 2000
    private let tradStarSize: CGFloat = 35
    private let tradStarSpacing: CGFloat = 10

    // --- Layout Moderno ---
    private let altBoxX: CGFloat = 86
    private let altBoxY: CGFloat = 736
    private let altBoxW: CGFloat = 1007
    private let altBoxH: CGFloat = 1007
    private let altBoxCorner: CGFloat = 32

    private let modPosterW: CGFloat = 400
    private let modPosterH: CGFloat = 600
    private var modPosterX: CGFloat { return altBoxX + altBoxW - modPosterW - 30 }
    private var modPosterY: CGFloat { return altBoxY + 30 }

    private var modYearPoint: CGPoint {
        return CGPoint(x: altBoxX + 30, y: altBoxY + 40)
    }
    private var modTitleRect: CGRect {
        let availableWidth = altBoxW - modPosterW - 100
        return CGRect(x: altBoxX + 30, y: modYearPoint.y + 60, width: availableWidth, height: 300)
    }

    private let modStarSize: CGFloat = 40
    private let modStarCount = 10
    private let modStarSpacing: CGFloat = 8

    // Riquadro test ruotato
    private let modRotatedBoxOrigin = CGPoint(x: 120, y: 850)
    private let modRotatedBoxSize = CGSize(width: 270, height: 850)

    func generatePoster(baseImage: UIImage, layout: String, movie: MovieModel) -> UIImage? {
        if layout == "modern" {
            return generateModern(base: baseImage, movie: movie)
        } else {
            return generateTraditional(base: baseImage, movie: movie)
        }
    }

    // MARK: - TRADITIONAL
    private func generateTraditional(base: UIImage, movie: MovieModel) -> UIImage? {
        let size = CGSize(width: iphoneWidth, height: iphoneHeight)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        let bgColor = averageColor(baseImage: base) ?? UIColor.white
        bgColor.setFill()
        context.fill(CGRect(origin: .zero, size: size))

        // Riquadro
        let outerRect = CGRect(x: tradQuadX, y: tradQuadY, width: tradQuadW, height: tradQuadH)
        UIColor.white.setFill()
        context.fill(outerRect)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(15)
        context.stroke(outerRect)

        // Poster
        let posterRect = CGRect(x: tradPosterX, y: tradPosterY, width: tradPosterW, height: tradPosterH)
        if let resizedPoster = base.resize(to: CGSize(width: tradPosterW, height: tradPosterH)) {
            resizedPoster.draw(in: posterRect)
        }

        // Testo titolo e anno
        let titleFont = UIFont.boldSystemFont(ofSize: 64)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        movie.title.draw(at: tradTitlePoint, withAttributes: titleAttrs)

        let yearFont = UIFont.boldSystemFont(ofSize: 28)
        let yearAttrs: [NSAttributedString.Key: Any] = [
            .font: yearFont,
            .foregroundColor: UIColor.black
        ]
        movie.year.draw(at: tradYearPoint, withAttributes: yearAttrs)

        // Stelline
        let rating = max(0, min(movie.rating, 10))
        for i in 0..<10 {
            let starX = tradStarsStartX + CGFloat(i) * (tradStarSize + tradStarSpacing)
            let rect = CGRect(x: starX, y: tradStarsY, width: tradStarSize, height: tradStarSize)
            let starImage = (i < rating) ? UIImage(systemName: "star.fill") : UIImage(systemName: "star")
            starImage?
                .withTintColor(.black, renderingMode: .alwaysOriginal)
                .draw(in: rect)
        }

        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return finalImage
    }

    // MARK: - MODERN
    private func generateModern(base: UIImage, movie: MovieModel) -> UIImage? {
        let size = CGSize(width: iphoneWidth, height: iphoneHeight)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        let baseAvg = averageColor(baseImage: base) ?? UIColor.darkGray
        let colorTop = baseAvg.withAlphaComponent(0.7)
        let colorBottom = UIColor.white.withAlphaComponent(0.7)
        let gradientColors = [colorTop.cgColor, colorBottom.cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: locations) {
            context.drawLinearGradient(gradient,
                                       start: .zero,
                                       end: CGPoint(x: 0, y: iphoneHeight),
                                       options: [])
        }

        let boxRect = CGRect(x: altBoxX, y: altBoxY, width: altBoxW, height: altBoxH)
        UIColor(white: 1.0, alpha: 0.8).setFill()
        let boxPath = UIBezierPath(roundedRect: boxRect, cornerRadius: altBoxCorner)
        boxPath.fill()

        // (Debug rectangle - facoltativo)
        let debugRect = CGRect(origin: modRotatedBoxOrigin, size: modRotatedBoxSize)
        let debugPath = UIBezierPath(rect: debugRect)
        UIColor.red.setStroke()
        debugPath.lineWidth = 2
        debugPath.stroke()

        let posterRect = CGRect(x: modPosterX, y: modPosterY, width: modPosterW, height: modPosterH)
        if let resizedPoster = base.resize(to: CGSize(width: modPosterW, height: modPosterH)) {
            let posterPath = UIBezierPath(roundedRect: posterRect, cornerRadius: 20)
            posterPath.addClip()
            resizedPoster.draw(in: posterRect)
        }

        let yearFont = UIFont.boldSystemFont(ofSize: 36)
        let yearAttrs: [NSAttributedString.Key: Any] = [
            .font: yearFont,
            .foregroundColor: UIColor.black
        ]
        movie.year.draw(at: modYearPoint, withAttributes: yearAttrs)

        let titleFont = UIFont.boldSystemFont(ofSize: 44)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle
        ]
        NSString(string: movie.title).draw(in: modTitleRect, withAttributes: titleAttrs)

        let rating = max(0, min(movie.rating, 10))
        let starCount = 10
        let starSize = modStarSize
        let starSpacing = modStarSpacing
        let starTotalWidth = CGFloat(starCount) * starSize + CGFloat(starCount - 1) * starSpacing
        let starStartX = boxRect.midX - starTotalWidth / 2
        let starY = boxRect.maxY - 60
        for i in 0..<starCount {
            let x = starStartX + CGFloat(i) * (starSize + starSpacing)
            let rect = CGRect(x: x, y: starY, width: starSize, height: starSize)
            if i < rating {
                UIImage(systemName: "star.fill")?
                    .withTintColor(.yellow, renderingMode: .alwaysOriginal)
                    .draw(in: rect)
            } else {
                UIImage(systemName: "star")?
                    .withTintColor(.gray, renderingMode: .alwaysOriginal)
                    .draw(in: rect)
            }
        }

        // Testo ruotato
        func wrapText(_ text: String, font: UIFont, maxWidth: CGFloat) -> String {
            let words = text.split(separator: " ")
            guard !words.isEmpty else { return "" }
            var lines: [String] = []
            var currentLine = String(words[0])
            for word in words.dropFirst() {
                let testLine = currentLine + " " + word
                let size = (testLine as NSString).size(withAttributes: [.font: font])
                if size.width <= maxWidth {
                    currentLine = testLine
                } else {
                    lines.append(currentLine)
                    currentLine = String(word)
                }
            }
            lines.append(currentLine)
            return lines.joined(separator: "\n")
        }

        func optimalFontSize(for text: String, maxWidth: CGFloat, maxHeight: CGFloat, fontName: String) -> CGFloat {
            var fs: CGFloat = 64
            while fs > 1 {
                let font = UIFont(name: fontName, size: fs) ?? UIFont.systemFont(ofSize: fs)
                let wrapped = wrapText(text, font: font, maxWidth: maxWidth)
                let bounding = (wrapped as NSString).boundingRect(
                    with: CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: [.font: font],
                    context: nil
                )
                if bounding.height <= maxHeight {
                    return fs
                }
                fs -= 1
            }
            return 1
        }

        let optimalSize = optimalFontSize(
            for: movie.title,
            maxWidth: modRotatedBoxSize.height,
            maxHeight: modRotatedBoxSize.width,
            fontName: "DejaVuSans-Bold"
        )
        let rotatedFont = UIFont(name: "DejaVuSans-Bold", size: optimalSize) ?? UIFont.boldSystemFont(ofSize: optimalSize)
        let wrappedTitle = wrapText(movie.title, font: rotatedFont, maxWidth: modRotatedBoxSize.height)

        UIGraphicsBeginImageContextWithOptions(modRotatedBoxSize, false, 1.0)
        (wrappedTitle as NSString).draw(
            in: CGRect(origin: .zero, size: modRotatedBoxSize),
            withAttributes: [.font: rotatedFont, .foregroundColor: UIColor.black]
        )
        let textImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        let rotatedTextImage = textImage.rotate(radians: .pi / 2)
        rotatedTextImage.draw(at: modRotatedBoxOrigin)

        // Stelline decorative
        let modStarSpacingAlt: CGFloat = 55
        let centerX = posterRect.midX
        let starYMod = posterRect.maxY - 50
        let totalStarWidthAlt = CGFloat(modStarCount - 1) * modStarSpacingAlt
        let leftX = centerX - totalStarWidthAlt / 2

        func starPolygon(cx: CGFloat, cy: CGFloat, rOut: CGFloat, rIn: CGFloat, n: Int = 5) -> [CGPoint] {
            var coords: [CGPoint] = []
            var angle = CGFloat.pi / 2
            let step = CGFloat.pi / CGFloat(n)
            for _ in 0..<(2 * n) {
                let r = (coords.count % 2 == 0) ? rOut : rIn
                let x = cx + r * cos(angle)
                let y = cy - r * sin(angle)
                coords.append(CGPoint(x: x, y: y))
                angle += step
            }
            return coords
        }

        let rOut: CGFloat = 20
        let rIn: CGFloat = 9
        for i in 0..<modStarCount {
            let sx = leftX + CGFloat(i) * modStarSpacingAlt
            let coords = starPolygon(cx: sx + rOut, cy: starYMod + rOut, rOut: rOut, rIn: rIn, n: 5)
            let path = UIBezierPath()
            if let first = coords.first {
                path.move(to: first)
                for pt in coords.dropFirst() {
                    path.addLine(to: pt)
                }
                path.close()
            }
            if i < rating {
                UIColor(red: 255/255, green: 215/255, blue: 0, alpha: 1.0).setFill()
                UIColor(red: 255/255, green: 215/255, blue: 0, alpha: 1.0).setStroke()
            } else {
                UIColor.white.setStroke()
            }
            path.lineWidth = 1
            path.fill()
            path.stroke()
        }

        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return finalImage
    }

    private func averageColor(baseImage: UIImage) -> UIColor? {
        guard let cgImage = baseImage.cgImage else { return nil }
        let width = 1, height = 1
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
        defer { rawData.deallocate() }

        guard let ctx = CGContext(data: rawData,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 4,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let r = CGFloat(rawData[0]) / 255.0
        let g = CGFloat(rawData[1]) / 255.0
        let b = CGFloat(rawData[2]) / 255.0
        let a = CGFloat(rawData[3]) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

extension UIImage {
    func rotate(radians: CGFloat) -> UIImage {
        let newSize = CGRect(origin: .zero, size: self.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return self }
        let origin = CGPoint(x: newSize.width / 2, y: newSize.height / 2)
        context.translateBy(x: origin.x, y: origin.y)
        context.rotate(by: radians)
        self.draw(in: CGRect(x: -self.size.width / 2,
                             y: -self.size.height / 2,
                             width: self.size.width,
                             height: self.size.height))
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return rotatedImage
    }

    func resize(to targetSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        self.draw(in: CGRect(origin: .zero, size: targetSize))
        let newImg = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImg
    }
}
