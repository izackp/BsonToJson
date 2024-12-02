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
    
    @Flag(help: "Use standard out instead of creating a new file.")
    var useStdOut: Bool = false
    
    @Flag(help: "Automatically overwrite existing files")
    var overwrite: Bool = false
    
    @Argument(help: "Path to file to convert", completion: .file(), transform: URL.init(fileURLWithPath:))
    var inputFile: URL? = nil
    
    @Argument(help: "Destination to write output", completion: .file(), transform: URL.init(fileURLWithPath:))
    var outputFile: URL? = nil

    
    var fileInHandle: FileHandle {
        get throws {
            guard let inputFile else {
                return .standardInput
            }
            return try FileHandle(forReadingFrom: inputFile)
        }
    }
    
    var fileOutHandle: FileHandle {
        get throws {
            let outFile:URL
            if let outputFile {
                outFile = outputFile
            } else {
                if (useStdOut) {
                    return FileHandle.standardOutput
                }
                if let inputFile = inputFile {
                    let ext = inputFile.pathExtension
                    let fileName = inputFile.lastPathComponent
                    let extIndex = fileName.index(fileName.startIndex, offsetBy: fileName.count - (ext.count + 1))
                    let withoutExt = fileName[fileName.startIndex..<extIndex]
                    let newOut = inputFile.deletingLastPathComponent().appendingPathComponent("\(withoutExt).json")
                    outFile = newOut
                } else {
                    throw AppError("Input File is required if useStdOut is not specified")
                }
            }
            let fm = FileManager.default
            if (fm.fileExists(atPath: outFile.path)) {
                if (overwrite) {
                    return try FileHandle(forWritingTo: outFile)
                } else {
                    throw AppError("File already exists. Specify overwrite to ignore. \(outFile.path)")
                }
            }
            guard fm.createFile(
                atPath: outFile.path,
                contents: nil,
                attributes: [:]
            ) else {
                throw AppError("Cannot access output file: \(outFile.path)")
            }
            return try FileHandle(forWritingTo: outFile)
        }
    }
    
    /*
    func withOut(_ out:(_ handle:FileHandle) throws ->()) throws {
        
            guard let outputFile else {
                try out(FileHandle.standardOutput)
                return
            }
            guard FileManager.default.createFile(
                atPath: outputFile.path,
                contents: nil,
                attributes: [:]
            ) else {
                throw AppError("Cannot access output file: \(outputFile.path)")
            }
            let handle = try FileHandle(forWritingTo: outputFile)
        
            try out(handle)
    }
    func write(_ data:Data) throws {
        var offset = 0
        let bufferSize = 4096 // Adjust buffer size as needed
        guard let outputFile else {

            //let handle = try fileOutHandle
            while offset < data.count {
                let chunkSize = min(data.count - offset, bufferSize)
                let chunk = data.subdata(in: offset..<offset + chunkSize)
                FileHandle.standardOutput.write(chunk)
                offset += chunkSize
            }
            
            return
        }
        guard FileManager.default.createFile(
            atPath: outputFile.path,
            contents: nil,
            attributes: [:]
        ) else {
            throw AppError("Cannot access output file: \(outputFile.path)")
        }
        let handle = try fileOutHandle
        while offset < data.count {
            let chunkSize = min(data.count - offset, bufferSize)
            let chunk = data.subdata(in: offset..<offset + chunkSize)
            handle.write(chunk)
            offset += chunkSize
        }
    }*/

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
        try fileOutHandle.write(jsonData)
        //try write(jsonData)
    }
}

let cmdLinArgs = CommandLine.arguments.dropFirst()
var args:[String] = Array(cmdLinArgs)

/*
if cmdLinArgs.count == 0 {
    args = ["*.bson"]
}*/
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
