import SwiftUI

struct MealplanPickerLayout<Plan: View, Picker: View>: View {
    let showsPicker: Bool
    @ContentBuilder let plan: () -> Plan
    @ContentBuilder let picker: () -> Picker

    var body: some View {
        if #available(iOS 27.1, *) {
            ArrangementView {
                plan()
            } secondary: {
                picker()
            }
            .arrangementViewStyle(.split.axes(showsPicker ? Axis.Set.horizontal : Axis.Set()))
        } else {
            HStack(spacing: 0) {
                plan().frame(maxWidth: .infinity)
                if showsPicker {
                    Divider()
                    picker().frame(maxWidth: .infinity)
                }
            }
        }
    }
}
