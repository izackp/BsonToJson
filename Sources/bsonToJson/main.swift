#!/usr/env/swift

import Foundation
import ArgumentParser
import BSON

if (CommandLine.arguments.count == 0) {
    print("Error: Expected at least 1 command line argument (the program directory)")
    exit(EXIT_FAILURE)
}

let workingDirectory:String = CommandLine.arguments[0]


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

extension URL {
    func convertExtension(_ newExt:String) -> URL {
        let ext = self.pathExtension
        let fileName = self.lastPathComponent
        let extIndex = fileName.index(fileName.startIndex, offsetBy: fileName.count - (ext.count + 1))
        let withoutExt = fileName[fileName.startIndex..<extIndex]
        let newOut = self.deletingLastPathComponent().appendingPathComponent("\(withoutExt).\(newExt)")
        return newOut
    }
}

extension FileManager {
    func listFiles(_ directory:URL, ext:String) throws -> [URL] {
        let fileIterator = try self.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants])
        let filesOnly = fileIterator.filter { (url) -> Bool in
            do {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                let isDirectory = resourceValues.isDirectory ?? true
                if (isDirectory) {
                    return false
                }
            } catch { return false }
            return url.pathExtension.lowercased() == ext
        }
        return filesOnly
    }
}

@available(macOS 10.15.4, *)
struct BsonToJson: ParsableCommand {
    
    static let configuration = CommandConfiguration(
            abstract: "A utility for converting bson files.",
            version: "0.2.0",
            subcommands: [io.self, batch.self],
            defaultSubcommand: batch.self)
    
    static func createFileOutHandle(_ url:URL, _ overwrite:Bool) throws -> FileHandle {
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
    
    struct batch: ParsableCommand {
        @Flag(name:[.customShort("f"), .long], help: "Automatically overwrite existing files")
        var overwrite: Bool = false
        
        @Argument(help: "Files to convert", completion: .file(), transform: URL.init(fileURLWithPath:))
        var inputFiles: [URL]
        
        func fetchInputFiles() throws -> [URL] {
            if inputFiles.count > 0 {
                return inputFiles
            }
            
            let fm = FileManager.default
            guard let workingDirUrl = URL(string: workingDirectory) else {
                throw AppError("Error: could not convert \(workingDirectory) to a url.")
            }
            
            let parentDirectory = workingDirUrl.deletingLastPathComponent()
            print("No dir. Scanning: \(parentDirectory.path)")
            let filesOnly = try fm.listFiles(parentDirectory, ext: "bson")
            print("Found \(filesOnly.count) files.")
            return filesOnly
        }

        mutating func run() throws {
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let urls = try fetchInputFiles()
            for eachUrl in urls {
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
                    
                    let newOut = eachUrl.convertExtension("json")
                    
                    let jsonData:Data = try encoder.encode(document)
                    let outHandle = try createFileOutHandle(newOut, overwrite)
                    outHandle.write(jsonData)
                    print("Success: \(newOut.path)")
                } catch {
                    print("Failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @available(macOS 10.15.4, *)
    struct io: ParsableCommand {
        
        @Flag(name:.long, help: "Use standard out instead of creating a new file.")
        var useStdOut: Bool = false
        
        @Flag(name:[.customShort("f"), .long], help: "Automatically overwrite existing files")
        var overwrite: Bool = false
        
        @Option(name:[.customShort("i"), .customLong("input")], help: "Path to file to convert", completion: .file(), transform: URL.init(fileURLWithPath:))
        var inputFile: URL? = nil
        
        @Option(name:[.customShort("o"), .customLong("output")], help: "Destination to write output", completion: .file(), transform: URL.init(fileURLWithPath:))
        var outputFile: URL? = nil

        
        var fileInHandle: FileHandle {
            get throws {
                guard let inputFile else {
                    return .standardInput
                }
                return try FileHandle(forReadingFrom: inputFile)
            }
        }
        
        func createFileOutHandle() throws -> FileHandle {
            let outFile:URL
            if let outputFile {
                outFile = outputFile
            } else {
                if (useStdOut) {
                    return FileHandle.standardOutput
                }
                if let inputFile = inputFile {
                    outFile = inputFile.convertExtension("json")
                } else {
                    throw AppError("Input File is required if useStdOut is not specified")
                }
            }
            return try BsonToJson.createFileOutHandle(outFile, overwrite)
        }

        mutating func run() throws {
            guard let data = try fileInHandle.readToEnd() else {
                throw AppError("Empty input.")
            }
            let document = Document(data: data)
            let validation = document.validate()
            if (validation.isValid == false) {
                throw AppError("Invalid bson at pos \(validation.errorPosition ?? -1)\nKey: \(validation.key ?? "N/A")\nReason: \(validation.reason ?? "N/A")")
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData:Data = try encoder.encode(document)
            try createFileOutHandle().write(jsonData)
        }
    }
}


let cmdLinArgs = CommandLine.arguments.dropFirst()
var args:[String] = Array(cmdLinArgs)

if #available(macOS 10.15.4, *) {
    BsonToJson.main(args)
} else {
    print("This only works on mac 10.15.4 and newer.")
    exit(EXIT_FAILURE)
}

exit(EXIT_SUCCESS)
