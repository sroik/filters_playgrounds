import UIKit
import CoreImage
import PlaygroundSupport

struct Size<T> {
    var width: T
    var height: T
}

extension CGImage {
    static func with(ciImage: CIImage) -> CGImage? {
        let ctx = CIContext(options: nil)
        let cgImage = ctx.createCGImage(ciImage, from: ciImage.extent)
        return cgImage
    }
    
    static func with(pixels: [BitmapPixel], size: Size<Int>) -> CGImage? {
        guard size.width * size.height == pixels.count else {
            return nil
        }
        
        let data = pixels.withUnsafeBufferPointer { Data(buffer: $0) }
        guard let providerRef = CGDataProvider(data: data as CFData) else {
            return nil
        }
        
        return CGImage(
            width: size.width,
            height: size.height,
            bitsPerComponent: BitmapPixel.bitsPerComponent,
            bitsPerPixel: BitmapPixel.bitsPerPixel,
            bytesPerRow: size.width * BitmapPixel.bytesPerPixel,
            space: BitmapPixel.colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: BitmapPixel.bitmapInfo),
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}

struct BitmapPixel {
    var a: UInt8
    var r: UInt8
    var g: UInt8
    var b: UInt8
    
    static var bitsPerComponent: Int {
        return 8
    }
    
    static var bitsPerPixel: Int {
        return bitsPerComponent * 4
    }
    
    static var bytesPerPixel: Int {
        return bitsPerPixel / 8
    }
    
    static var alphaInfo: UInt32 {
        return CGImageAlphaInfo.premultipliedFirst.rawValue
    }
    
    static var bitmapInfo: UInt32 {
        return CGBitmapInfo.byteOrder32Big.rawValue | alphaInfo
    }
    
    static var colorSpace: CGColorSpace {
        return CGColorSpaceCreateDeviceRGB()
    }
    
    static var identity: BitmapPixel {
        return BitmapPixel(a: 0, r: 0, g: 0, b: 0)
    }
}

extension UIColor {
    var bitmapPixel: BitmapPixel {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return BitmapPixel(
            a: UInt8(a * 255),
            r: UInt8(r * 255),
            g: UInt8(g * 255),
            b: UInt8(b * 255)
        )
    }
}

////////////////////////////////////////////////////////////////
/////////////////// FILTERS ////////////////////////////////////
////////////////////////////////////////////////////////////////

class PaletteConversionFilter {
    
    var inputImage: CIImage?
    var palette: [BitmapPixel] = [.identity]
    
    var outputImage: CIImage? {
        guard let inputImage = inputImage, let paletteImage = paletteImage, let kernel = kernel else {
            return nil
        }
        
        let roiCallback: CIKernelROICallback = { idx, dest in
            return dest
        }
        
        let args: [AnyObject] = [
            inputImage,
            NSNumber(value: Float(palette.count)),
            paletteImage
        ]
        
        return kernel.apply(extent: inputImage.extent, roiCallback: roiCallback, arguments: args)
    }
    
    private var paletteImage: CIImage? {
        guard let cgImage = CGImage.with(pixels: palette, size: Size(width: palette.count, height: 1)) else {
            return nil
        }
        
        return CIImage(cgImage: cgImage)
    }
    
    private lazy var kernel: CIKernel? = {
        guard
            let kernelURL = Bundle.main.url(forResource: "palette_conversion_filter", withExtension: "kernel"),
            let kernelString = try? String(contentsOf: kernelURL)
        else {
            return nil
        }
        
        return CIKernel(source: kernelString)
    }()
}

class BilateralFilter {
    
    var inputImage: CIImage?
    var inputRadius: Int = 5
    var inputThreshold: Double = 0.08
    
    var outputImage: CIImage? {
        guard let inputImage = inputImage, let kernel = kernel else {
            return nil
        }
        
        let roiCallback: CIKernelROICallback = { [r = inputRadius] idx, dest in
            return dest.insetBy(dx: -CGFloat(r), dy: -CGFloat(r))
        }
        
        let args: [AnyObject] = [
            inputImage,//.clampedToExtent(),
            NSNumber(value: inputRadius * 2),
            NSNumber(value: inputRadius * 4),
            NSNumber(value: inputThreshold)
        ]
        
        return kernel.apply(extent: inputImage.extent, roiCallback: roiCallback, arguments: args)
    }
    
    private lazy var kernel: CIKernel? = {
        guard
            let kernelURL = Bundle.main.url(forResource: "bilateral_filter", withExtension: "kernel"),
            let kernelString = try? String(contentsOf: kernelURL)
        else {
            return nil
        }
        
        return CIKernel(source: kernelString)
    }()
}

extension CIImage {
    func converted(to palette: [BitmapPixel]) -> CIImage {
        let filter = PaletteConversionFilter()
        filter.palette = palette
        filter.inputImage = self
        return filter.outputImage ?? self
    }
    
    func bilateral(radius: Int = 3, threshold: Double = 0.8) -> CIImage {
        let filter = BilateralFilter()
        filter.inputImage = self
        filter.inputRadius = radius
        filter.inputThreshold = threshold
        let output = filter.outputImage ?? self
        return output
    }
}

////////////////////////////////////////////////////////////////
/////////////////// SAMPLES ////////////////////////////////////
////////////////////////////////////////////////////////////////

guard let image = UIImage(named: "img.png"), let cgImage = image.cgImage else {
    fatalError("image doesn't exist")
}

let input = CIImage(cgImage: cgImage)

let bilateral = input.bilateral()

let paletteColors: [UIColor] = [.red, .yellow, .gray, .white, .black, .brown, .green, .purple, .cyan]
let palette = paletteColors.map { $0.bitmapPixel }
let paletted = input.converted(to: palette)




