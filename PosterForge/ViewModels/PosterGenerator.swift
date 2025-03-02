import UIKit
import CoreGraphics
import CoreImage

class PosterGenerator {
    static let shared = PosterGenerator()

    private let iphoneWidth: CGFloat = 1179
    private let iphoneHeight: CGFloat = 2556

    // Layout Tradizionale
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

    // Stelle
    private let tradStarsYAdjust: CGFloat = 250 // spostamento in basso
    private let tradStarSize: CGFloat = 35
    private let tradStarSpacing: CGFloat = 10

    // Layout Moderno
    private let altBoxX: CGFloat = 86
    private let altBoxY: CGFloat = 736
    private let altBoxW: CGFloat = 1007
    private let altBoxH: CGFloat = 1007
    private let altBoxCorner: CGFloat = 32

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

        let bgColor = averageColor(baseImage: base) ?? .white
        bgColor.setFill()
        context.fill(CGRect(origin: .zero, size: size))

        // Riquadro
        let rect = CGRect(x: tradQuadX, y: tradQuadY, width: tradQuadW, height: tradQuadH)
        UIColor.white.setFill()
        context.fill(rect)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(15)
        context.stroke(rect)

        // Poster
        let posterRect = CGRect(x: tradPosterX, y: tradPosterY, width: tradPosterW, height: tradPosterH)
        if let resized = base.resize(to: CGSize(width: tradPosterW, height: tradPosterH)) {
            resized.draw(in: posterRect)
        }

        // Titolo
        let titleFont = UIFont.boldSystemFont(ofSize: 64)
        let titleAttrs: [NSAttributedString.Key : Any] = [
            .font: titleFont, .foregroundColor: UIColor.black
        ]
        movie.title.draw(at: tradTitlePoint, withAttributes: titleAttrs)

        // Anno 2 righe
        let yearFont = UIFont.boldSystemFont(ofSize: 26)
        let year = movie.year
        if year.count == 4 {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 0
            style.alignment = .left
            let compound = "\(year.prefix(2))\n\(year.suffix(2))"
            let attributed = NSAttributedString(string: compound, attributes: [
                .font: yearFont,
                .foregroundColor: UIColor.black,
                .paragraphStyle: style
            ])
            attributed.draw(at: tradYearPoint)
        } else {
            let yearAttrs: [NSAttributedString.Key : Any] = [
                .font: yearFont, .foregroundColor: UIColor.black
            ]
            movie.year.draw(at: tradYearPoint, withAttributes: yearAttrs)
        }

        // Stelle
        let starCount = 10
        let totalWidth = CGFloat(starCount) * tradStarSize + CGFloat(starCount - 1)*tradStarSpacing
        let rMidX = rect.midX
        let startX = rMidX - totalWidth/2
        let baseY = CGFloat(2000 + tradStarsYAdjust)
        let rating = max(0, min(movie.rating, 10))
        for i in 0..<starCount {
            let x = startX + CGFloat(i)*(tradStarSize+tradStarSpacing)
            let starRect = CGRect(x: x, y: baseY, width: tradStarSize, height: tradStarSize)
            let starImage = (i<rating) ? UIImage(systemName: "star.fill") : UIImage(systemName: "star")
            starImage?.withTintColor(.black, renderingMode: .alwaysOriginal).draw(in: starRect)
        }

        let final = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return final
    }

    // MARK: - MODERN
    private func generateModern(base: UIImage, movie: MovieModel) -> UIImage? {
        let size = CGSize(width: iphoneWidth, height: iphoneHeight)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        let baseAvg = averageColor(baseImage: base) ?? .darkGray
        let cTop = baseAvg.darker(by: 30)
        let cBot = UIColor.black
        let gradColors = [cTop.cgColor, cBot.cgColor] as CFArray
        let locs: [CGFloat] = [0, 1]
        let space = CGColorSpaceCreateDeviceRGB()
        if let grad = CGGradient(colorsSpace: space, colors: gradColors, locations: locs) {
            ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x:0, y:size.height), options: [])
        }

        let boxRect = CGRect(x: altBoxX, y: altBoxY, width: altBoxW, height: altBoxH)
        UIColor(white: 1, alpha: 0.8).setFill()
        let boxPath = UIBezierPath(roundedRect: boxRect, cornerRadius: altBoxCorner)
        boxPath.fill()

        // Poster intero
        let posterRectH = boxRect.height - 60
        let ratio = base.size.width / base.size.height
        let computedW = posterRectH * ratio
        let finalPosterRect = CGRect(
            x: boxRect.maxX - computedW - 30,
            y: boxRect.minY + 30,
            width: computedW,
            height: posterRectH
        )
        if let resized = base.resize(to: CGSize(width: computedW, height: posterRectH)) {
            let posterClip = UIBezierPath(roundedRect: finalPosterRect, cornerRadius:20)
            posterClip.addClip()
            resized.draw(in: finalPosterRect)
        }

        // Anno
        let yearFont = UIFont.boldSystemFont(ofSize:36)
        let yearAttrs:[NSAttributedString.Key:Any] = [
            .font: yearFont,
            .foregroundColor: UIColor.black
        ]
        let yearPoint = CGPoint(x: boxRect.minX + 40, y: boxRect.minY + 40)
        movie.year.draw(at: yearPoint, withAttributes: yearAttrs)

        // Titolo
        let tFont = UIFont.boldSystemFont(ofSize:44)
        let pStyle = NSMutableParagraphStyle()
        pStyle.lineBreakMode = .byWordWrapping
        let tAttrs:[NSAttributedString.Key:Any] = [
            .font: tFont,
            .foregroundColor: UIColor.black,
            .paragraphStyle: pStyle
        ]
        let titleX = boxRect.minX + 40
        let titleY = yearPoint.y + 60
        let titleMaxW = boxRect.width - (computedW + 100)
        let rectTitle = CGRect(x: titleX, y: titleY, width: titleMaxW, height: 300)
        NSString(string: movie.title).draw(in: rectTitle, withAttributes: tAttrs)

        // Stelle
        let rating = max(0, min(movie.rating, 10))
        let starCount = 10
        let starSize: CGFloat = 40
        let starSpacing: CGFloat = 8
        let stTotW = CGFloat(starCount)*starSize + CGFloat(starCount-1)*starSpacing
        let stX = boxRect.midX - stTotW/2
        let stY = boxRect.maxY - 70
        for i in 0..<starCount {
            let x = stX + CGFloat(i)*(starSize+starSpacing)
            let stRect = CGRect(x:x, y:stY, width:starSize, height:starSize)
            if i<rating {
                UIImage(systemName: "star.fill")?
                    .withTintColor(.yellow, renderingMode: .alwaysOriginal)
                    .draw(in: stRect)
            } else {
                UIImage(systemName: "star")?
                    .withTintColor(.gray, renderingMode: .alwaysOriginal)
                    .draw(in: stRect)
            }
        }

        let final = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return final
    }

    private func averageColor(baseImage: UIImage) -> UIColor? {
        guard let cg = baseImage.cgImage else {return nil}
        let w=1, h=1
        let space = CGColorSpaceCreateDeviceRGB()
        let raw = UnsafeMutablePointer<UInt8>.allocate(capacity:4)
        defer { raw.deallocate() }
        guard let cxt = CGContext(data: raw, width: w, height: h, bitsPerComponent:8, bytesPerRow:4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else{return nil}
        cxt.draw(cg, in:CGRect(x:0,y:0,width:1,height:1))
        let r = CGFloat(raw[0])/255.0
        let g = CGFloat(raw[1])/255.0
        let b = CGFloat(raw[2])/255.0
        let a = CGFloat(raw[3])/255.0
        return UIColor(red:r, green:g, blue:b, alpha:a)
    }
}

extension UIColor {
    func darker(by percentage: CGFloat=20.0)->UIColor{
        var (h, s, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        if getHue(&h, saturation:&s, brightness:&b, alpha:&a) {
            let nb = max(min(b-percentage/100.0,1.0),0.0)
            return UIColor(hue:h, saturation:s, brightness:nb, alpha:a)
        }
        return self
    }
}

extension UIImage {
    func resize(to target: CGSize)->UIImage?{
        UIGraphicsBeginImageContextWithOptions(target, false,1.0)
        draw(in: CGRect(origin:.zero,size:target))
        let newImg = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImg
    }
}
