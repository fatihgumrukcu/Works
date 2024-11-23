//
//  PromptLabApp.swift
//  PromptLab
//
//  Created by Fatih on 15.11.2024.
//

import SwiftUI

@main
struct PromptLabApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            PromptView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
