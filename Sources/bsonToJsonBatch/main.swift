#!/usr/env/swift

import Foundation
import ArgumentParser
import BSON

struct AppError: LocalizedError {
    
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    init(_ message: String, _ error:Error) {
        self.message = "\(message) : \(error.localizedDescription)"
    }
    
    static func failure<T>(_ message: String) -> Result<T, AppError> {
        return .failure(AppError(message))
    }
    
    var errorDescription: String? {
        get {
            return message
        }
    }
    
    var localizedDescription: String {
        get {
            return message
        }
    }
}

@available(macOS 10.15.4, *)
struct ConvertBsonToJson: ParsableCommand {
    @Argument(help: "Files to convert", completion: .file(), transform: URL.init(fileURLWithPath:))
    var inputFiles: [URL]

    mutating func run() throws {
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        for eachUrl in inputFiles {
            print("creating handle: \(eachUrl.path)")
            let inputHandle = try FileHandle(forReadingFrom: eachUrl)
            guard let data = try inputHandle.readToEnd() else {
                throw AppError("Empty input.")
            }
            print("Validating")
            let document = Document(data: data)
            let validation = document.validate()
            if (validation.isValid == false) {
                throw AppError("Invalid bson at pos \(validation.errorPosition ?? -1)\nKey: \(validation.key ?? "N/A")\nReason: \(validation.reason ?? "N/A")")
            }
            
            print("Is Valid")
            let ext = eachUrl.pathExtension
            let fileName = eachUrl.lastPathComponent
            let extIndex = fileName.index(fileName.startIndex, offsetBy: fileName.count - (ext.count + 1))
            let withoutExt = fileName[fileName.startIndex..<extIndex]
            let newOut = eachUrl.deletingLastPathComponent().appendingPathComponent("\(withoutExt).json")
            
            print("creating file: \(newOut.path)")
            guard FileManager.default.createFile(
                atPath: newOut.path,
                contents: nil,
                attributes: [:]
            ) else {
                throw AppError("Cannot access output file: \(newOut.path)")
            }
            
            print("Creating handle for: \(newOut.path)")
            let outHandle = try FileHandle(forWritingTo: newOut)
            let jsonData:Data = try encoder.encode(document)
            outHandle.write(jsonData)
        }
    }
}

let cmdLinArgs = CommandLine.arguments.dropFirst()
var args:[String] = Array(cmdLinArgs)

if #available(macOS 10.15.4, *) {
    do {
        var command = ConvertBsonToJson.parseOrExit(args)
        try command.validate()
        try command.run()
    } catch {
        print("Error: \(error.localizedDescription)")
    }
} else {
    print("This only works on mac 10.15.4 and newer.")
}
