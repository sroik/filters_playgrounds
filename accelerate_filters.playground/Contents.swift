import UIKit
import Foundation
import CoreGraphics
import Accelerate
import PlaygroundSupport

enum Filter {
    case none
    case gaussBlur
    case edge
    case sharp
    
    var convolutionMatrix: [[Int16]] {
        switch self {
        case .none:
            return [[0, 0, 0],
                    [0, 1, 0],
                    [0, 0, 0]]
        case .edge:
            return [[0, 1, 0],
                    [1,-4, 1],
                    [0, 1, 0]]
        case .gaussBlur:
            return [[1, 2, 1],
                    [2, 6, 2],
                    [1, 2, 1]]
        case .sharp:
            return [[0, -1, 0],
                    [-1, 5, -1],
                    [0, -1, 0]]
        }
    }
    
    var convolutionDivisor: Int32 {
        switch self {
        case .none, .edge, .sharp: return 1
        case .gaussBlur: return 16
        }
    }
}

extension CGImage {
    
    func convolve(with filter: Filter) -> CGImage {
        return convolve(with: filter.convolutionMatrix, divisor: filter.convolutionDivisor)
    }
    
    func convolve(with kernel: [[Int16]], divisor: Int32 = 1) -> CGImage {
        let vHeight = vImagePixelCount(height)
        let vWidth = vImagePixelCount(width)
        let vBitsPerPixel = UInt32(bitsPerPixel)

        var inputFormat = vImage_CGImageFormat()
        var inputBuffer = vImage_Buffer()
        vImageBuffer_InitWithCGImage(&inputBuffer, &inputFormat, nil, self, vImage_Flags(kvImageNoFlags))
        
        var outputBuffer = vImage_Buffer()
        vImageBuffer_Init(&outputBuffer, vHeight, vWidth, vBitsPerPixel, vImage_Flags(kvImageNoFlags))
        
        var backgroundColor : Array<UInt8> = [0, 0, 0, 0]
        let flatKernel = kernel.flatMap { $0 }
        let (kernelW, kernelH) = (UInt32(kernel.first?.count ?? 0), UInt32(kernel.count))

        var kernels: [UnsafePointer<Int16>?] = [
            UnsafePointer(flatKernel),
            UnsafePointer(flatKernel),
            UnsafePointer(flatKernel),
            UnsafePointer([0, 0, 0, 0, 1, 0, 0, 0, 0])
        ]

        let divisors = [divisor, divisor, divisor, 1]
        let biases: [Int32] = [0, 0, 0, 0]

        let convolutionError = vImageConvolveMultiKernel_ARGB8888(
            &inputBuffer, &outputBuffer,
            nil, 0, 0,
            &kernels,
            kernelH, kernelW,
            divisors, biases, &backgroundColor,
            UInt32(kvImageBackgroundColorFill)
        )

//        let convolutionError = vImageConvolve_ARGB8888(
//            &inputBuffer, &outputBuffer, nil, 0, 0,
//            flatKernel, kernelH, kernelW, divisor,
//            &backgroundColor, UInt32(kvImageBackgroundColorFill)
//        )
        
        print("convolution error: ", convolutionError)
        
        var error: vImage_Error = 0
        let result = vImageCreateCGImageFromBuffer(
            &outputBuffer, &inputFormat,
            nil, nil,
            vImage_Flags(kvImageNoFlags),
            &error
        )
        
        guard let image = result?.takeRetainedValue() else {
            fatalError("error occured: \(error)")
        }
        
        let size = vImageBuffer_GetSize(&inputBuffer)
        let count = Int(size.width * size.height * 4)
        var pointer = inputBuffer.data.bindMemory(to: UInt8.self, capacity: count)
        var buffer = UnsafeBufferPointer(start: pointer, count: count)
        print("input data: ", Array(buffer)[0...15])
        
        pointer = outputBuffer.data.bindMemory(to: UInt8.self, capacity: count)
        buffer = UnsafeBufferPointer(start: pointer, count: count)
        print("output data: ", Array(buffer)[0...15])
        
        print("applied filter: ", flatKernel, kernelW, kernelH, divisor, ", error: ", error)
        return image
    }
}

let imageView = UIImageView()
imageView.contentMode = .scaleAspectFit
imageView.frame = CGRect(x: 0, y: 0, width: 200, height: 200)

guard let image = UIImage(named: "img_small.png"), let cgImage = image.cgImage else {
    fatalError("image doesn't exist")
}

imageView.image = image

imageView.image = UIImage(cgImage: cgImage.convolve(with: Filter.sharp))

imageView.image = UIImage(cgImage: cgImage.convolve(with: Filter.edge))

imageView.image = UIImage(cgImage: cgImage.convolve(with: Filter.gaussBlur))

