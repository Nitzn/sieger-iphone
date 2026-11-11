// Export the existing SIEGER feather design as an opaque iPhone AppIcon.
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                        bytesPerRow: 4096, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor { CGColor(red: red/255, green: green/255, blue: blue/255, alpha: 1) }
context.setFillColor(color(245,235,213)); context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.translateBy(x: 0, y: 1024); context.scaleBy(x: 4, y: -4)
context.setFillColor(color(186,148,78))
let points: [CGPoint] = [(67,190),(65,153),(77,114),(99,82),(131,57),(173,40),(216,31),(208,79),(188,119),(160,153),(127,176),(94,190)].map { CGPoint(x: CGFloat($0.0), y: CGFloat($0.1)) }
context.addLines(between: points); context.closePath(); context.fillPath()
context.setStrokeColor(color(128,95,45)); context.setLineWidth(7); context.setLineCap(.round)
context.move(to: CGPoint(x:52,y:217));context.addQuadCurve(to: CGPoint(x:201,y:47),control:CGPoint(x:115,y:142));context.strokePath()
context.setStrokeColor(color(245,235,213));context.setLineWidth(4)
for line in [[77,119,109,130],[94,91,128,108],[118,68,149,87],[123,176,130,132],[152,155,151,110],[181,126,173,84]] {
    context.move(to:CGPoint(x:CGFloat(line[0]),y:CGFloat(line[1])));context.addLine(to:CGPoint(x:CGFloat(line[2]),y:CGFloat(line[3])));context.strokePath()
}
let folder=URL(fileURLWithPath:"SIEGER/Assets.xcassets/AppIcon.appiconset",isDirectory:true)
try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
let destination=CGImageDestinationCreateWithURL(folder.appendingPathComponent("AppIcon.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(destination,context.makeImage()!,nil)
guard CGImageDestinationFinalize(destination) else { fatalError("AppIcon export failed") }
