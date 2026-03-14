import SwiftUI

struct HabitView: View {
    var body: some View {
        ZStack {
            Makam.bg.ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundStyle(Makam.gold.opacity(0.5))

                Text("Alışkanlıklar")
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundStyle(Makam.sandDim)
            }
        }
    }
}
