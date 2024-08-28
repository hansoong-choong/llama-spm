//
//  ContentView.swift
//  minicpm
//
//  Created by hansoong choong on 15/8/24.
//

import PhotosUI
import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var llamaState : LlamaState
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: ImageData?
    @State var showProgress : Bool = false
    @State var message : String = ""
    @State var timer = Timer.publish (every: 100, on: .current, in: .common).autoconnect()
    @State var prompt : String = "Describe the image in details"
    //@State var language : OutputLanguage = .ENGLISH
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                PhotosPicker("Select a picture", selection: $pickerItem, matching: .images)
                    .disabled(llamaState.appStatus != .READY)
                Spacer()
                TextField("Prompt", text: $prompt)
                    .disableAutocorrection(true)
                    .frame(width : 350)
                    .onSubmit {
                        if let _ = llamaState.fileURL {
                            llamaState.message = ""
                            self.message = "loading prediction ..."
                            self.timer = Timer.publish (every: 0.5, on: .current, in: .common).autoconnect()
                            Task {
                                llamaState.appStatus = .BUSY
                                await llamaState.runPrediction(imagePath: llamaState.fileURL!.path(), prompt : self.prompt)
                                llamaState.appStatus = .READY
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    self.timer.upstream.connect().cancel()
                                }
                            }
                        }
                    }
//                Spacer()
//                Picker("Language:", selection: $llamaState.language) {
//                        ForEach(Language.allCases, id: \.self) { item in
//                            Text(String(describing: item))
//                        }
//                }
//                .pickerStyle(.radioGroup)
                Spacer()
                Button {
                    Task {
                        await llamaState.testTextEmbed(prompt: self.prompt)
                        self.message = "\(llamaState.embeding)"
                    }
                } label: {
                    HStack {
                        Image(systemName: "t.circle")
                        Text("Text Embed")
                    }
                }.disabled(llamaState.appStatus == .EMPTY)
                Button {
                        llamaState.downloadALL()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Download MiniCPMv 2.6")
                    }
                }.disabled(llamaState.appStatus != .EMPTY)
            }.disabled(llamaState.appStatus == .BUSY)
            Spacer()
            HStack {
                ZStack {
                    ZStack(alignment:.topLeading) {
                        if imageData != nil {
                            Image(nsImage: NSImage(data: imageData!.data)!)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .opacity(showProgress ? 1 : 0)
                }
                .padding()
                .frame(width: 400, height: 400)
                ZStack {
                    VStack {
                        TextEditor(text:$message)
                            .frame(height: 400)
                            .font(.system(size: llamaState.language == .ENGLISH ? 14 : 18))
                            .padding()
                            .lineSpacing(10)
                            .multilineTextAlignment(.leading)
                            .padding()
                    }
                }
                .frame(width: 500)
            }
            Spacer()
            Text(llamaState.status)
                .font(.system(size: 16))
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding()
        .onChange(of: pickerItem) {
            llamaState.message = ""
            self.timer = Timer.publish (every: 0.5, on: .current, in: .common).autoconnect()
            Task {
                if let imageData = try await pickerItem?.loadTransferable(type: ImageData.self) {
                    self.imageData = imageData
                    self.showProgress = true
                    self.message = "loading prediction ..."
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        Task {
                            if let fileURL = llamaState.writetoDoc(data: imageData.data) {
                                llamaState.fileURL = fileURL
                                llamaState.appStatus = .BUSY
                                await llamaState.runPrediction(imagePath: fileURL.path(), prompt : self.prompt)
                                llamaState.appStatus = .READY
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    self.timer.upstream.connect().cancel()
                                }
                            }
                            self.showProgress = false
                        }
                    }
                }
                
            }
        }
        .onReceive(timer) { _ in
            if llamaState.message.count > 0 {
                self.message = llamaState.message
            }
        }
        .onChange(of: llamaState.language) {
            if let _ = llamaState.fileURL {
                llamaState.message = ""
                self.message = ""
                self.timer = Timer.publish (every: 0.5, on: .current, in: .common).autoconnect()
                Task {
                    llamaState.appStatus = .BUSY
                    await llamaState.runPrediction(imagePath: llamaState.fileURL!.path(), prompt : self.prompt)
                    llamaState.appStatus = .READY
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.timer.upstream.connect().cancel()
                    }
                }
            }
        }
        .onAppear {
            message = llamaState.message
        }
    }
}
