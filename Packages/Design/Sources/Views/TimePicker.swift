//
//  TimePicker.swift
//  Sporkast
//

import SwiftUI

public struct TimePicker: View {
    var style: AnyShapeStyle = .init(.bar)
    @Binding private var duration: Duration
    
    private let hourRange: ClosedRange<Int>
    private let minuteRange: ClosedRange<Int>
    
    public init(
        style: AnyShapeStyle = .init(.bar),
        duration: Binding<Duration>,
        hourRange: ClosedRange<Int> = 0...99,
        minuteRange: ClosedRange<Int> = 0...59
    ) {
        self.style = style
        self._duration = duration
        self.hourRange = hourRange
        self.minuteRange = minuteRange
    }
    
    private var hoursBinding: Binding<Int> {
        Binding(
            get: {
                let totalSeconds = duration.components.seconds
                return max(hourRange.lowerBound, min(hourRange.upperBound, Int(totalSeconds) / 3600))
            },
            set: { newHours in
                let clampedHours = max(hourRange.lowerBound, min(hourRange.upperBound, newHours))
                let minutes = minutesBinding.wrappedValue
                duration = .seconds(Int64(clampedHours * 3600 + minutes * 60))
            }
        )
    }
    
    private var minutesBinding: Binding<Int> {
        Binding(
            get: {
                let totalSeconds = duration.components.seconds
                let mins = (totalSeconds % 3600) / 60
                return max(minuteRange.lowerBound, min(minuteRange.upperBound, Int(mins)))
            },
            set: { newMinutes in
                let clampedMinutes = max(minuteRange.lowerBound, min(minuteRange.upperBound, newMinutes))
                let hours = hoursBinding.wrappedValue
                duration = .seconds(Int64(hours * 3600 + clampedMinutes * 60))
            }
        )
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            customView("hours", hourRange, hoursBinding)
            customView("mins", minuteRange, minutesBinding)
        }
        .offset(x: -25)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(style)
                .frame(height: 35)
        }
    }
    
    @ViewBuilder
    private func customView(_ title: String, _ range: ClosedRange<Int>, _ selection: Binding<Int>) -> some View {
        PickerViewWithoutIndicator(selection: selection) {
            ForEach(range, id: \.self) { value in
                Text("\(value)")
                    .frame(width: 35, alignment: .trailing)
                    .tag(value)
            }
        }
        .overlay {
            Text(title)
                .font(.callout.bold())
                .frame(width: 50, alignment: .leading)
                .lineLimit(1)
                .offset(x: 50)
        }
    }
}


/// Helpers
struct PickerViewWithoutIndicator<Content: View, Selection: Hashable>: View {
    @Binding var selection: Selection
    @ViewBuilder var content: Content
    @State private var isHidden: Bool = false
    var body: some View {
        Picker("", selection: $selection) {
            if !isHidden {
                RemovePickerIndicator {
                    isHidden = true
                }
            } else {
                content
            }
        }
        .pickerStyle(.wheel)
    }
}

fileprivate
struct RemovePickerIndicator: UIViewRepresentable {
    var result: () -> ()
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            if let pickerView = view.pickerView {
                if pickerView.subviews.count >= 2 {
                    pickerView.subviews[1].backgroundColor = .clear
                }
                result()
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {  }
}

fileprivate
extension UIView {
    var pickerView: UIPickerView? {
        if let view = superview as? UIPickerView {
            return view
        }
        
        return superview?.pickerView
    }
}
