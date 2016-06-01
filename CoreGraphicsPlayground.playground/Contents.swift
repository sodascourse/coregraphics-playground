//: Playground - noun: a place where people can play

import Foundation
import CoreGraphics
import ImageIO

#if os(iOS)
    import MobileCoreServices
    import UIKit.UIColor
    typealias ColorType = UIColor
    typealias ImageType = UIImage
#else
    import CoreServices
    import AppKit.NSColor
    typealias ColorType = NSColor
    typealias ImageType = NSImage
#endif

//: # Create CGContext

#if os(iOS)
    func drawInUIKitContext(size: CGSize, block: (CGContext) -> Void) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, true, 0.0)
        defer {
            UIGraphicsEndImageContext()
        }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        block(context)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
#endif

func createBitmapContext(ofSize size: CGSize) -> CGContext? {
    let width = Int(size.width)
    let height = Int(size.height)
    let bitsPerComponent = 8
    let bytesPerRow = 4*bitsPerComponent*width/8  // RGBA
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue)
    guard let colorSpace = CGColorSpaceCreateDeviceRGB() else { return nil }
    guard let context = CGBitmapContextCreate(nil, width, height, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo.rawValue) else {
        return nil
    }
    resetCoordinate(ofContext: context, size: size)
    return context
}

func createPDFContext(outputData: NSMutableData, ofSize size: CGSize) -> CGContext? {
    // NOTE: Remember to `begin` a new page, `end` it, and call `close`
    guard let dataConsumer = CGDataConsumerCreateWithCFData(outputData) else { return nil }
    var rect = CGRect(origin: CGPoint.zero, size: size)
    guard let context = CGPDFContextCreate(dataConsumer, &rect, nil) else { return nil }
    resetCoordinate(ofContext: context, size: size)
    return context
}

//:
//: The coordinate system of CoreGrpahics is the same as AppKit (OS X).
//:
//: For AppKit and CoreGraphics, the origin is at the left-bottom corner, the X-axis is towarding to the right,
//: and the Y-axis is to the top.
//:
//: For UIKit (iOS and tvOS), the origin is at the left-top corner, and the Y-axis is pointing to the bottom.
//:

func resetCoordinate(ofContext context: CGContext, size: CGSize) {
#if os(iOS)
    // Transform the coordinate to the same as UIKit.
    var transform = CGAffineTransformMakeTranslation(0.0, size.height)
    transform = CGAffineTransformScale(transform, 1.0, -1.0)
    CGContextConcatCTM(context, transform)
#endif
}

//: # Data representation of CGImage

extension CGImage {
    func getBitmapData() -> NSData? {
        guard let dataProvider = CGImageGetDataProvider(self) else { return nil }
        return CGDataProviderCopyData(dataProvider)
    }

    func getTIFFData() -> NSData? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, kUTTypeTIFF, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, self, nil)
        CGImageDestinationFinalize(destination)
        return NSData(data: mutableData)
    }

    func getImage() -> ImageType {
        #if os(iOS)
            return ImageType(CGImage: self)
        #else
            return ImageType(CGImage: self, size: NSSize(width: CGImageGetWidth(self), height: CGImageGetHeight(self)))
        #endif
    }
}

// I/O
func storagePath() -> String? {
    return NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first
}

// Let's draw a circle

func drawCircle(radius: CGFloat, color: ColorType) -> CGImage? {
    let size = CGSize(width: radius*2, height: radius*2)
    guard let context = createBitmapContext(ofSize: size) else { return nil }

    CGContextSaveGState(context)
    CGContextSetFillColorWithColor(context, color.CGColor)
    CGContextFillEllipseInRect(context, CGRect(origin: CGPoint.zero, size: size))
    CGContextRestoreGState(context)

    return CGBitmapContextCreateImage(context)
}
let circleCGImage = drawCircle(100.0, color: ColorType.orangeColor())!
let circleImage = circleCGImage.getImage()
let circleImageData = circleCGImage.getTIFFData()!
let circleImagePath = (storagePath()! as NSString).stringByAppendingPathComponent("circle.tiff")
try! circleImageData.writeToFile(circleImagePath, options: .AtomicWrite)

// Let's do some image manipulation

#if os(iOS)

extension UIImage {

    func scale(toSize size: CGSize) -> UIImage? {
        guard let context = createBitmapContext(ofSize: size) else { return nil }

        CGContextSaveGState(context)
        // CGContextDrawImage still draws images in CoreGraphics's coordination
        CGContextTranslateCTM(context, 0.0, size.height);
        CGContextScaleCTM(context, 1.0, -1.0);
        CGContextDrawImage(context, CGRect(origin: CGPoint.zero, size: size), self.CGImage)
        CGContextRestoreGState(context)

        guard let cgImage = CGBitmapContextCreateImage(context) else { return nil }
        return UIImage(CGImage: cgImage)
    }

    func crop(toRect cropRect: CGRect) -> UIImage? {
        return drawInUIKitContext(cropRect.size) { context in
            CGContextSaveGState(context)
            CGContextTranslateCTM(context, -cropRect.origin.x, -cropRect.origin.y)
            self.drawInRect(CGRect(origin: CGPoint.zero, size: self.size))
            CGContextRestoreGState(context)
        }
    }

    func colored(withColor color: UIColor, blendMode: CGBlendMode) -> UIImage? {
        // Check `CoreImage` for further image effects
        return drawInUIKitContext(self.size) { context in
            let fullRect = CGRect(origin: CGPoint.zero, size: self.size)

            CGContextSaveGState(context)
            self.drawInRect(fullRect)
            CGContextRestoreGState(context)

            CGContextSaveGState(context)
            CGContextSetFillColorWithColor(context, color.CGColor)
            CGContextSetBlendMode(context, blendMode)
            CGContextFillRect(context, fullRect)
            CGContextRestoreGState(context)
        }
    }

}

let 東京タワー_2016_Image = [#Image(imageLiteral: "東京タワー 2016.jpg")#]
let smaller_tokyo_tower = 東京タワー_2016_Image.scale(toSize: CGSize(width: 800, height: 600))!
let cropped_tokyo_tower = 東京タワー_2016_Image.crop(toRect: CGRect(x: 1500, y: 800, width: 400, height: 1000))

let alphaBlue = UIColor.blueColor().colorWithAlphaComponent(0.5)
let blue_tokyo_tower = smaller_tokyo_tower.colored(withColor: alphaBlue, blendMode: .Multiply)

#endif
