//
//  minicpmApp.swift
//  minicpm
//
//  Created by hansoong choong on 15/8/24.
//

import SwiftUI

@main
struct minicpmApp: App {
    @StateObject var llamaState = LlamaState()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(llamaState)
        }
        .defaultSize(width: 900, height: 600)
    }
}
