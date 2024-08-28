import SwiftUI
import PhotosUI

struct ContentView: View {
    
    @EnvironmentObject var llamaState : LlamaState
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: ImageData?
    @State var showProgress : Bool = false
    @State var message : String = ""
    @State var timer = Timer.publish (every: 100, on: .current, in: .common).autoconnect()
    @State var prompt : String = "Describe the image in details"
    @State var showPicker : Bool = false
    //@State var language : OutputLanguage = .ENGLISH
    
    var promptView : some View {
        TextField("Prompt", text: $prompt)
            .disableAutocorrection(true)
        //.frame(width : 350)
            .onSubmit {
                if let fileURL = llamaState.fileURL {
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
    }
    var body: some View {
        NavigationStack {
            VStack {
                promptView
                ZStack {
                    ZStack(alignment:.topLeading) {
                        if imageData != nil {
                            Image(uiImage: UIImage(data: imageData!.data)!)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .opacity(showProgress ? 1 : 0)
                }
                .padding()
                TextEditor(text:$message)
                    .font(.system(size: llamaState.language == .ENGLISH ? 14 : 18))
                    .padding()
                    .lineSpacing(10)
                    .multilineTextAlignment(.leading)
                    .padding()
                Text(llamaState.status)
                    .font(.system(size: 16))
                    .multilineTextAlignment(.leading)
            }.toolbar {
                Button {
                    showPicker.toggle()
                } label: {
                    Text("Image")
                }
                .photosPicker(isPresented: $showPicker, selection: $pickerItem)
                .disabled(llamaState.appStatus != .READY)
                //ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        llamaState.downloadALL()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Download MiniCPMv 2.6")
                        }
                    }.disabled(llamaState.appStatus != .EMPTY)
                //}
               // }.disabled(llamaState.appStatus == .BUSY)
            }
            
        }
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
            if let fileURL = llamaState.fileURL {
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

//Button {
//    llamaState.testTextEmbed(prompt: self.prompt)
//} label: {
//    HStack {
//        Image(systemName: "t.circle")
//        Text("Text Embed")
//    }
//}.disabled(llamaState.appStatus == .EMPTY)
