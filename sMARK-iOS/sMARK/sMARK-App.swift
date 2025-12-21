//
//  project_ios1App.swift
//  project-ios1
//
//  Created by çağla on 14.12.2025.
//

import SwiftUI
import FirebaseCore // Firebase kütüphanesini içeri alıyoruz

// 1. Firebase'i başlatan yardımcı sınıf
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    print("Firebase başarıyla bağlandı!") // Bağlantıyı test etmek için konsola yazı yazdırır
    return true
  }
}

@main
struct project_ios1App: App {
  // 2. Yukarıdaki ayarı SwiftUI projesine bağlıyoruz
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

  var body: some Scene {
    WindowGroup {
      ContentView() // Uygulama açıldığında görünecek ilk ekran
    }
  }
}
