import SwiftUI

struct DateTextSizeSheet: View {
    @Binding var showDateTextSize: Double
    @Environment(\.dismiss) private var dismiss

    private let range: ClosedRange<Double> = 10...24

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Adjust how large show dates appear across the app.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Slider(value: $showDateTextSize, in: range, step: 1)
                        .accessibilityLabel("Show date text size")
                        .accessibilityValue("\(Int(showDateTextSize)) point")
                    HStack {
                        Text("Small")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("Large")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text("Sat, Mar 15 · 8:00 PM")
                        .font(.system(size: showDateTextSize, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("CardBackground"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(20)
            .navigationTitle("Date Text Size")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
