import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioManager: AudioManager
    @State private var selectedTuning: Tuning?
    @State private var selectedStringNote: StringNote?

    private let frequencies: [Double] = [30, 41, 82, 110, 146, 196, 246, 329, 440, 500, 880, 1000]

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height) * 0.8
 
            VStack {
                Spacer()

                // Algılanan nota ismi
                Text(audioManager.noteName.isEmpty ? "" : audioManager.noteName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(audioManager.isTuned ? .green : .red)
                    .padding(.bottom, 20)

                Spacer()

                // Çember ve ibre görünümü
                ZStack {
                    FrequencyIndicatorCircle(frequencies: frequencies)
                        .frame(width: size, height: size)

                    NeedleView(
                        frequency: audioManager.frequency == 0 ? 0 : max(audioManager.frequency, frequencies.first!), // Başlangıçta sabit, sonra dinamik
                        minFrequency: frequencies.first!,
                        maxFrequency: frequencies.last!
                    )
                    .frame(width: size, height: size)
                }
                .frame(width: size, height: size)

                Spacer()

                // Takibi başlat/durdur butonu
                Button(audioManager.audioEngine.isRunning ? "Takibi Durdur" : "Takibi Başlat") {
                    if audioManager.audioEngine.isRunning {
                        audioManager.stopTracking()
                    } else {
                        audioManager.startTracking()
                    }
                }
                .padding()
                .background(audioManager.audioEngine.isRunning ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .animation(.easeInOut, value: audioManager.audioEngine.isRunning)

                Spacer()
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .onAppear {
            initializeAudioManager()
        }
    }

    private func initializeAudioManager() {
        audioManager.loadTunings()
        if selectedTuning == nil, let firstTuning = audioManager.tunings.first {
            selectedTuning = firstTuning
        }
        if let tuning = selectedTuning {
            audioManager.setTargetTuning(tuning)
            if selectedStringNote == nil {
                selectedStringNote = tuning.tuning.first { $0.string == 6 }
            }
            if let stringNote = selectedStringNote {
                audioManager.setTargetFrequency(for: stringNote)
            }
        }
    }
}

// Frekans çemberini çizen bileşen
struct FrequencyIndicatorCircle: View {
    let frequencies: [Double]

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let outerRadius = size / 2 - 20

            ZStack {
                // Çember arka planı
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 25)

                // Frekans etiketleri ve uzun çizgiler
                ForEach(0..<frequencies.count, id: \.self) { index in
                    let angle = Angle(degrees: 360.0 / Double(frequencies.count) * Double(index) - 90)

                    // Frekans etiketleri
                    Text("\(Int(frequencies[index])) Hz")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .rotationEffect(angle + .degrees(90))
                        .position(circularPosition(for: angle, radius: outerRadius + 35, center: center))

                    // Uzun çizgiler
                    Path { path in
                        let start = circularPosition(for: angle, radius: outerRadius - 12, center: center)
                        let end = circularPosition(for: angle, radius: outerRadius + 5, center: center)
                        path.move(to: start)
                        path.addLine(to: end)
                    }
                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                }

                // Kısa çizgiler
                ForEach(0..<frequencies.count, id: \.self) { index in
                    let angle = Angle(degrees: 360.0 / Double(frequencies.count) * Double(index) - 90)

                    ForEach(1..<4, id: \.self) { subIndex in
                        let subAngle = angle + Angle(degrees: 360.0 / Double(frequencies.count) / 4 * Double(subIndex))
                        Path { path in
                            let start = circularPosition(for: subAngle, radius: outerRadius - 18, center: center)
                            let end = circularPosition(for: subAngle, radius: outerRadius - 8, center: center)
                            path.move(to: start)
                            path.addLine(to: end)
                        }
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    }
                }
            }
            .frame(width: size, height: size)
        }
    }

    private func circularPosition(for angle: Angle, radius: CGFloat, center: CGPoint) -> CGPoint {
        let x = center.x + radius * cos(CGFloat(angle.radians))
        let y = center.y + radius * sin(CGFloat(angle.radians))
        return CGPoint(x: x, y: y)
    }
}

// İbre bileşeni
struct NeedleView: View {
    let frequency: Double
    let minFrequency: Double
    let maxFrequency: Double

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let angle = calculateAngle()

            ZStack {
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 6, height: size * 0.4)
                    .offset(y: -size * 0.2)
                    .rotationEffect(angle) // İğnenin açısı
                    .animation(.easeInOut, value: frequency)
            }
            .frame(width: size, height: size)
        }
    }

    private func calculateAngle() -> Angle {
        if frequency == 0 {
            // Başlangıçta iğne saat 12 yönünde sabit dursun
            return .degrees(-90)
        } else {
            // Frekansa göre açıyı hesapla
            let clampedFrequency = min(max(frequency, minFrequency), maxFrequency)
            let normalizedValue = (clampedFrequency - minFrequency) / (maxFrequency - minFrequency)
            return .degrees(normalizedValue * 180 - 90)
        }
    }
}

