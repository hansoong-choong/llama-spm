import Foundation
import llama
import SwiftUI

struct Model: Identifiable {
    var id = UUID()
    var name: String
    var url: String
    var filename: String
    var status: String?
}

enum LMMModelType {
    case LLM
    case CLIP
}

enum AppStatus {
    case DOWNLOADING
    case READY
    case EMPTY
    case BUSY
}

enum Language: CaseIterable, Identifiable, CustomStringConvertible {
    
    case ENGLISH
    case CHINESE
    
    var id: Self { self }
    
    var description: String {
            switch self {
            case .ENGLISH:
                return "English"
            default:
                return "中文"
            }
        }
}

class LlamaState: ObservableObject {
    @Published var cacheCleared = false

    
    var message : String = ""
    var embeding : [Float] = []
    
    @Published var appStatus: AppStatus = .EMPTY
    @Published var status: String = ""
    @Published var language : Language = .ENGLISH
    var fileURL : URL? = nil
    
    
    //download related
    var progressLLM = 0.0
    var progressCLIP = 0.0
    var observationLLM: NSKeyValueObservation?
    var observationCLIP: NSKeyValueObservation?
    let llmmodel = "ggml-model-Q4_0.gguf"
    
    init() {
        updateStatus()
    }
    
    func updateStatus() {
        appStatus = checkStatus()
        status = getStatusString()
    }
    
    let NS_PER_S = 1_000_000_000.0
    
    func getStatusString() -> String {
        var status = ""
        if appStatus == .EMPTY {
            status = "*Please download models first"
        } else if appStatus == .READY {
            status = "Ready"
        }
        
        if progressLLM > 0.001 && progressCLIP > 0.001 {
            status = "download LLM \(Int(progressLLM * 100))%, CLIP \(Int(progressCLIP * 100))%"
        } else if progressCLIP > 0.001 {
            status = "download CLIP \(Int(progressCLIP * 100))%"
        } else if progressLLM > 0.001 {
            status = "download LLM \(Int(progressLLM * 100))%"
        }
        return status
    }
    
    func checkStatus() -> AppStatus {
        if
        FileManager.default.fileExists(atPath: getLocalModelURLFor(type: .LLM).path()) &&
            FileManager.default.fileExists(atPath: getLocalModelURLFor(type: .CLIP).path()) {
            return .READY
        } else if self.progressLLM > 0.001 || self.progressCLIP > 0.001 {
            return .DOWNLOADING
        }
        return .EMPTY
    }
    
    func getLocalModelURLFor(type : LMMModelType) -> URL {
        let documentsPath = getDocumentsDirectory().path()
        switch type {
        case .LLM:
            return URL(filePath:"\(documentsPath)cpm/\(llmmodel)")
        case .CLIP:
            return URL(filePath:"\(documentsPath)cpm/mmproj-model-f16.gguf")
        }
    }

    func writetoDoc(data: Data) -> URL? {
        do {
            // get the documents directory url
            let directoryURL = getDocumentsDirectory()
            let tempDirectoryURL = directoryURL.appendingPathComponent("temp")
            try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            let fileName = "image.jpg"
            // create the destination file url to save your image
            let fileURL = tempDirectoryURL.appendingPathComponent(fileName)
            // get your UIImage jpeg data representation and check if the destination file url already exists
            // writes the image data to disk
            try data.write(to: fileURL)
            return fileURL
        
        } catch {
            print("error:", error)
            return nil
        }
    }
    
    
    func testTextEmbed(prompt: String) async {
        let documentsPath = getDocumentsDirectory().path()
        let llmPath = "\(documentsPath)cpm/\(llmmodel)"
        let prompt = prompt.count > 0 ? prompt : "describe the image in detail"
        
        let args = ["progr_name", "-m", llmPath, "--pooling", "mean", "-p", prompt]
        var cargs = args.map { strdup($0) }
        
        let p1 = Unmanaged.passRetained(self).toOpaque()
        
        let _ = run_text_encoding(Int32(args.count), &cargs, p1, { s_object, embeding, count in
            guard let s_object = s_object else {
                return true
            }
            let p2 = Unmanaged<LlamaState>.fromOpaque(s_object).takeUnretainedValue()
            //DispatchQueue.main.async {
            if count > 0 {
                let fpointer : UnsafePointer<Float> = embeding!
                let buffer = UnsafeBufferPointer(start: fpointer, count: Int(count))
                p2.embeding = Array(buffer)
            }
            return true
        })
    }
    
    func runPrediction(imagePath: String, prompt: String) async {
        let documentsPath = getDocumentsDirectory().path()
        let llmPath = "\(documentsPath)cpm/\(llmmodel)"
        let clipPath = "\(documentsPath)cpm/mmproj-model-f16.gguf"
        //let imagePath = "\(documentsPath)3ppl_small.jpg"
        let imagePath = imagePath
        
        let prompt = prompt.count > 0 ? prompt : "describe the image in detail"
        //var swift_object = Swift_Content()
        let _ = print("imagePath = \(imagePath)")
        let args = ["progr_name", "-m", llmPath, "--mmproj", clipPath,
                    "--image", imagePath, "-p", prompt]
        var cargs = args.map { strdup($0) }
        
        let p1 = Unmanaged.passRetained(self).toOpaque()

        let _ = run_minicpm(Int32(args.count), &cargs, p1, { s_object, cstr in
            
            guard let s_object = s_object else {
                return true
            }
            let p2 = Unmanaged<LlamaState>.fromOpaque(s_object).takeUnretainedValue()
            //DispatchQueue.main.async {
            p2.message = String(cString: cstr!)
            
            return true
        })
    }
    
    func getDocumentsDirectory() -> URL {
        let fileManager = FileManager.default
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func prepareModelFolder() {
        
        
        let imagesPath = getDocumentsDirectory().appendingPathComponent("cpm")
        do
        {
            try FileManager.default.createDirectory(atPath: imagesPath.path, withIntermediateDirectories: true, attributes: nil)
        }
        catch let error as NSError
        {
            NSLog("Unable to create directory \(error.debugDescription)")
        }
    }
    
    func downloadALL() {
        FileManager.default.clearTmpDirectory()
        prepareModelFolder()
        
        self.appStatus = .DOWNLOADING
        
        let urlsPath : [String] = ["https://huggingface.co/openbmb/MiniCPM-V-2_6-gguf/resolve/main/\(llmmodel)?download=true",
                                   "https://huggingface.co/openbmb/MiniCPM-V-2_6-gguf/resolve/main/mmproj-model-f16.gguf?download=true"]
        for urlPath in urlsPath {
            download(modelURL: URL(string: urlPath), for: urlPath.contains("mmproj-model-f16.gguf") ? .CLIP : .LLM)
        }
    }
    
    private func download(modelURL : URL?, for type: LMMModelType) {
        
        guard let url = modelURL else { return }
        
        var downloadTask: URLSessionDownloadTask?
        var observation: NSKeyValueObservation?
        
        downloadTask = URLSession.shared.downloadTask(with: url) { temporaryURL, response, error in
            let _ = print("download complete")
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            
            guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                print("Server error!")
                return
            }
            
            do {
                
                if let temporaryURL = temporaryURL {
                    let fileURL = self.getLocalModelURLFor(type: type)
                    let _ = print("fileURL = \(fileURL)")
                    try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
                    
                    print("Writing to \(fileURL) completed")
                    DispatchQueue.main.sync {
                        switch type {
                        case .CLIP:
                            self.progressCLIP = 0.0
                        case .LLM:
                            self.progressLLM = 0.0
                        }
                        self.updateStatus()
                    }
                }
            } catch let err {
                print("Error: \(err.localizedDescription)")
            }
        }
        
        observation = downloadTask?.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                switch type {
                case .CLIP:
                    self.progressCLIP = progress.fractionCompleted
                    //let _ = print("progressCLIP = \(self.progressCLIP)")
                case .LLM:
                    self.progressLLM = progress.fractionCompleted
                    //let _ = print("progressLLM = \(self.progressLLM)")
                }
                self.updateStatus()
            }
        }
        let _ = print("downloadTask = \(downloadTask!)")
        let _ = print("observation = \(observation!)")
        if type == .CLIP {
            observationLLM = observation
        } else {
            observationCLIP = observation
        }
        downloadTask?.resume()
    }
}

enum TransferError : Error {
        case importFailed
}

struct ImageData: Transferable {
    let data: Data
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
        #if canImport(AppKit)
            guard let _ = NSImage(data: data) else {
                throw TransferError.importFailed
            }
            return ImageData(data: data)
        #elseif canImport(UIKit)
            guard let _ = UIImage(data: data) else {
                throw TransferError.importFailed
            }
            return ImageData(data: data)
        #else
            throw TransferError.importFailed
        #endif
        }
    }
}

extension FileManager {
    func clearTmpDirectory() {
        do {
            let tmpDirectory = try contentsOfDirectory(atPath: NSTemporaryDirectory())
            let _ = print("temp = \(tmpDirectory)")
            try tmpDirectory.forEach {[unowned self] file in
                let path = String.init(format: "%@%@", NSTemporaryDirectory(), file)
                try self.removeItem(atPath: path)
            }
        } catch {
            print(error)
        }
    }
}
