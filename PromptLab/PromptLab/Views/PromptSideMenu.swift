import SwiftUI

struct PromptSideMenu: View {
    @Binding var isMenuVisible: Bool // Menü durumunu kontrol eden bağlamalı değişken

    var body: some View {
        VStack(alignment: .leading) {
            // Menü Başlığı (Bir kısa, bir uzun çizgi)
            HStack(spacing: 6) { // Çizgiler arasındaki boşluk
                Rectangle()
                    .frame(width: 20, height: 4) // Kısa çizgi
                    .cornerRadius(2)
                Rectangle()
                    .frame(width: 35, height: 4) // Uzun çizgi
                    .cornerRadius(2)
            }
            .padding(.top, 50)
            .padding(.horizontal)
            
            Divider()
            
            // Menü Öğeleri
            Button(action: {
                print("Bir işlem yapıldı")
                isMenuVisible = false // Menü kapatılır
            }) {
                Text("Menü Öğesi 1")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Button(action: {
                print("Bir başka işlem yapıldı")
                isMenuVisible = false // Menü kapatılır
            }){
        }
            Spacer()
        }
        .frame(maxWidth: 300)
        .background(Color(UIColor.systemBackground))
        .shadow(radius: 5)
        .edgesIgnoringSafeArea(.all)
    }
}
