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
    @Flag(help: "Automatically overwrite existing files")
    var overwrite: Bool = false
    
    @Argument(help: "Files to convert", completion: .file(), transform: URL.init(fileURLWithPath:))
    var inputFiles: [URL]
    
    func createFileHandle(_ url:URL) throws -> FileHandle {
        let fm = FileManager.default
        if (fm.fileExists(atPath: url.path)) {
            if (overwrite) {
                return try FileHandle(forWritingTo: url)
            } else {
                throw AppError("File already exists. Specify overwrite to ignore. \(url.path)")
            }
        }
        
        guard fm.createFile(
            atPath: url.path,
            contents: nil,
            attributes: [:]
        ) else {
            throw AppError("Cannot access output file: \(url.path)")
        }
        let outHandle = try FileHandle(forWritingTo: url)
        return outHandle
    }

    mutating func run() throws {
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        for eachUrl in inputFiles {
            do {
                print("Processing: \(eachUrl.path)")
                let inputHandle = try FileHandle(forReadingFrom: eachUrl)
                guard let data = try inputHandle.readToEnd() else {
                    throw AppError("Empty input.")
                }
                
                let document = Document(data: data)
                let validation = document.validate()
                if (validation.isValid == false) {
                    throw AppError("Invalid bson at pos \(validation.errorPosition ?? -1)\nKey: \(validation.key ?? "N/A")\nReason: \(validation.reason ?? "N/A")")
                }
                
                let ext = eachUrl.pathExtension
                let fileName = eachUrl.lastPathComponent
                let extIndex = fileName.index(fileName.startIndex, offsetBy: fileName.count - (ext.count + 1))
                let withoutExt = fileName[fileName.startIndex..<extIndex]
                let newOut = eachUrl.deletingLastPathComponent().appendingPathComponent("\(withoutExt).json")
                
                let jsonData:Data = try encoder.encode(document)
                let outHandle = try createFileHandle(newOut)
                outHandle.write(jsonData)
                print("Success: \(newOut.path)")
            } catch {
                print("Failed: \(error.localizedDescription)")
            }
        }
    }
}

if (CommandLine.arguments.count == 0) {
    print("Error: Expected at least 1 command line argument (the program directory)")
    exit(1)
}

let cmdLinArgs = CommandLine.arguments.dropFirst()
var args:[String] = Array(cmdLinArgs)

if cmdLinArgs.count == 0 {
    let fm = FileManager.default
    let workingDir = CommandLine.arguments[0]//fm.currentDirectoryPath
    guard let workingDirUrl = URL(string: workingDir) else {
        print("Error: could not convert \(workingDir) to a url.")
        exit(1)
    }
    let parentDirectory = workingDirUrl.deletingLastPathComponent()
    print("No dir. Scanning: \(parentDirectory.path)")
    //fm.enumerator(at: parentDirectory, includingPropertiesForKeys: [URLResourceKey.isDirectoryKey])
    let fileIterator = try fm.contentsOfDirectory(at: parentDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants])
    let filesOnly = fileIterator.filter { (url) -> Bool in
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = resourceValues.isDirectory ?? true
            if (isDirectory) {
                return false
            }
        } catch { return false }
        return url.pathExtension.lowercased() == "bson"
    }
    
    let fileList = filesOnly.map({ $0.path })
    if (fileList.count == 0) {
        print("No bson files found")
        exit(0)
    } else {
        print("Found \(fileList.count) files.")
    }
    args = fileList
}

if #available(macOS 10.15.4, *) {
    do {
        var command = ConvertBsonToJson.parseOrExit(args)
        try command.validate()
        try command.run()
    } catch {
        print("Error: \(error.localizedDescription)")
        exit(1)
    }
} else {
    print("This only works on mac 10.15.4 and newer.")
    exit(1)
}
