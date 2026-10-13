import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import NativeRender

/// craft.files' disk side: the files it makes, the JPEG a picked photo becomes,
/// the multipart body a screen's FormData is sent as, and a refused download.
/// The pickers themselves need a person; what they hand on is tested here.
@MainActor
final class FilesUnitTests: XCTestCase {
    func testNamesCarryNoPath() {
        XCTAssertEqual(CraftNativeFiles.safeName("../../etc/passwd"), "-..-etc-passwd")
        XCTAssertEqual(CraftNativeFiles.safeName(".hidden"), "hidden")
        XCTAssertEqual(CraftNativeFiles.safeName("  "), "file")
        XCTAssertEqual(CraftNativeFiles.jpegName("IMG_1234.HEIC"), "IMG_1234.jpg")
        XCTAssertEqual(CraftNativeFiles.jpegName(nil), "photo.jpg")
    }

    func testOnlyFilesMadeHereAreOwned() throws {
        let made = try CraftNativeFiles.newFile(named: "route.gpx")
        try Data("<gpx/>".utf8).write(to: made)
        XCTAssertEqual(CraftNativeFiles.owned(made.path)?.lastPathComponent, "route.gpx")
        XCTAssertNil(CraftNativeFiles.owned(made.deletingLastPathComponent().path), "a folder is not a file")
        XCTAssertNil(CraftNativeFiles.owned(made.deletingLastPathComponent().appendingPathComponent("../../../Library/Preferences/x.plist").path))
        XCTAssertNil(CraftNativeFiles.owned(Bundle.main.bundlePath + "/Info.plist"))
        XCTAssertTrue(CraftNativeFiles.remove(made.path))
        XCTAssertNil(CraftNativeFiles.owned(made.path))
        XCTAssertFalse(CraftNativeFiles.remove(made.path))
    }

    func testAPhotoBecomesAnUprightJPEGNoLargerThanAsked() throws {
        let size = CGSize(width: 400, height: 300)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let png = UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            UIColor.orange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
        guard case .success(let value) = CraftNativeFiles.writeJPEG(from: source, maxPixels: 200, quality: 0.8, name: "IMG_1.jpg") else {
            return XCTFail("the photo was not written")
        }
        let info = try XCTUnwrap(value as? [String: Any])
        XCTAssertEqual(info["type"] as? String, "image/jpeg")
        XCTAssertEqual(info["name"] as? String, "IMG_1.jpg")
        XCTAssertEqual(info["width"] as? Int, 200)
        XCTAssertEqual(info["height"] as? Int, 150)
        let path = try XCTUnwrap(info["path"] as? String)
        XCTAssertGreaterThan(info["size"] as? Int ?? 0, 0)
        let written = try XCTUnwrap(CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetType(written) as String?, UTType.jpeg.identifier)
        XCTAssertTrue(CraftNativeFiles.remove(path))
    }

    func testAFormIsSentAsMultipartWithItsFile() throws {
        let made = try CraftNativeFiles.newFile(named: "IMG_2.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: made)
        guard case .success(let (body, boundary)) = CraftNativeFiles.multipart([
            ["name": "caption", "value": "Long run"],
            ["name": "photo", "path": made.path, "filename": "my \"best\".jpg", "type": "image/jpeg"],
        ]) else {
            return XCTFail("the form was refused")
        }
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(boundary.hasPrefix("craft-"))
        XCTAssertTrue(text.hasPrefix("--\(boundary)\r\nContent-Disposition: form-data; name=\"caption\"\r\n\r\nLong run\r\n"))
        XCTAssertTrue(text.contains("Content-Disposition: form-data; name=\"photo\"; filename=\"my %22best%22.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n"))
        XCTAssertTrue(body.range(of: Data([0xFF, 0xD8, 0xFF, 0xD9])) != nil, "the file's bytes are in the body")
        XCTAssertTrue(text.hasSuffix("\r\n--\(boundary)--\r\n"))
        CraftNativeFiles.remove(made.path)
    }

    func testAFormNamesNoFileItDidNotMake() {
        guard case .failure(let error) = CraftNativeFiles.multipart([["name": "photo", "path": Bundle.main.bundlePath + "/Info.plist"]]) else {
            return XCTFail("an arbitrary file was read into a form")
        }
        XCTAssertEqual(error.code, "INVALID_ARGUMENT")
        guard case .failure = CraftNativeFiles.multipart([["value": "no name"]]) else {
            return XCTFail("a part with no name was sent")
        }
    }

    func testARefusedDownloadSaysWhyAndKeepsNothing() throws {
        let body = FileManager.default.temporaryDirectory.appendingPathComponent("refused-\(UUID().uuidString).json")
        try Data(#"{"error":"Activity not found"}"#.utf8).write(to: body)
        let response = try XCTUnwrap(HTTPURLResponse(url: URL(string: "https://example.com/route.gpx")!, statusCode: 404, httpVersion: nil, headerFields: nil))
        let answer = CraftNativeFiles.refusedDownload(at: body, response: response)
        XCTAssertEqual(answer["ok"] as? Bool, false)
        XCTAssertEqual(answer["status"] as? Int, 404)
        XCTAssertEqual(answer["body"] as? String, #"{"error":"Activity not found"}"#)
        XCTAssertNil(answer["path"])
        try? FileManager.default.removeItem(at: body)
    }

    func testADownloadIsKeptUnderTheServersName() throws {
        let location = FileManager.default.temporaryDirectory.appendingPathComponent("download-\(UUID().uuidString).tmp")
        try Data("<gpx/>".utf8).write(to: location)
        let response = try XCTUnwrap(HTTPURLResponse(url: URL(string: "https://example.com/api/activities/9/gpx")!, statusCode: 200, httpVersion: nil, headerFields: [
            "Content-Type": "application/gpx+xml",
            "Content-Disposition": "attachment; filename=\"2026-10-12-long-run.gpx\"",
        ]))
        guard case .success(let value) = CraftNativeFiles.keepDownload(at: location, response: response, name: nil) else {
            return XCTFail("the download was not kept")
        }
        let info = try XCTUnwrap(value as? [String: Any])
        XCTAssertEqual(info["name"] as? String, "2026-10-12-long-run.gpx")
        XCTAssertEqual(info["type"] as? String, "application/gpx+xml")
        XCTAssertEqual(info["ok"] as? Bool, true)
        XCTAssertEqual(info["status"] as? Int, 200)
        XCTAssertNotNil(CraftNativeFiles.owned(info["path"] as? String ?? ""))
        CraftNativeFiles.remove(info["path"] as? String ?? "")
    }
}
