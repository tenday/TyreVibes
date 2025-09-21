//
//  ContentView.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 14/09/25.
//


import SwiftUI
import Charts


struct TyreDetailView: View {
    @State private var selectedTyre = "FL"
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.customBackgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Header with car info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Make")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            
                            HStack {
                                Text("Toyota")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            HStack {
                                Text("Model")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            
                            HStack {
                                Text("Camry SE")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            HStack {
                                Text("Season")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            
                            HStack {
                                Text("Winter")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            HStack {
                                Text("DOT")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            
                            HStack {
                                Text("1A2B 0323")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Tyre visual representation
                        HStack {
                            Spacer()
                            TyreVisualizationView()
                                .frame(width: 200, height: 200)
                            Spacer()
                        }
                        .padding(.vertical, 20)
                        
                        // Tread depth measurements
                        VStack(spacing: 20) {
                            HStack(spacing: 40) {
                                TreadDepthCard(
                                    position: "FL",
                                    depth: "7.2 mm",
                                    progress: 0.9,
                                    color: .green
                                )
                                
                                TreadDepthCard(
                                    position: "FR",
                                    depth: "7.2 mm",
                                    progress: 0.9,
                                    color: .green
                                )
                            }
                            
                            HStack(spacing: 40) {
                                TreadDepthCard(
                                    position: "RL",
                                    depth: "4.0 mm",
                                    progress: 0.5,
                                    color: .orange
                                )
                                
                                TreadDepthCard(
                                    position: "RR",
                                    depth: "2.5 mm",
                                    progress: 0.25,
                                    color: .red
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Remaining life
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Remaining Life")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            
                            HStack {
                                Text("80%")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            ProgressView(value: 0.8)
                                .progressViewStyle(CustomProgressViewStyle(color: .cyan))
                                .frame(height: 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                        
                        // Tire Lifecycle Chart
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Tire Lifecycle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            TireLifecycleChart()
                                .frame(height: 200)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                        
                        // Compatible Tire Dimensions
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Compatible Tire Dimensions")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            VStack(spacing: 12) {
                                TireDimensionRow(
                                    label: "Standard:",
                                    dimension: "255/50 R19 107W",
                                    isRecommended: true
                                )
                                
                                TireDimensionRow(
                                    label: "Alternative:",
                                    dimension: "285/45 R19 111W",
                                    isRecommended: false
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                        
                        // Tire Condition
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Tire Condition")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            HStack(spacing: 20) {
                                TireConditionIcon()
                                
                                HStack(spacing: 25) {
                                    TireConditionBar(position: "FL", percentage: 70, color: .green)
                                    TireConditionBar(position: "FR", percentage: 80, color: .green)
                                    TireConditionBar(position: "RL", percentage: 30, color: .orange)
                                    TireConditionBar(position: "RR", percentage: 35, color: .red)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {}) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Tyre Name")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "arrow.down.to.line")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                    }
                }
                
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
    }
}

struct TyreVisualizationView: View {
    var body: some View {
        ZStack {
            // Main tire circle
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 180, height: 180)
            
            // Inner rim
            Circle()
                .fill(Color.gray.opacity(0.6))
                .frame(width: 120, height: 120)
            
            // Rim spokes
            ForEach(0..<6) { spoke in
                Rectangle()
                    .fill(Color.gray.opacity(0.8))
                    .frame(width: 4, height: 40)
                    .offset(y: -20)
                    .rotationEffect(.degrees(Double(spoke) * 60))
            }
            
            // Center hub
            Circle()
                .fill(Color.gray.opacity(0.9))
                .frame(width: 30, height: 30)
        }
    }
}

struct TreadDepthCard: View {
    let position: String
    let depth: String
    let progress: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tread Depth")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
                Text(position)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(depth)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            ProgressView(value: progress)
                .progressViewStyle(CustomProgressViewStyle(color: color))
                .frame(height: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CustomProgressViewStyle: ProgressViewStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 6)
                    .cornerRadius(3)
                
                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0), height: 6)
                    .cornerRadius(3)
            }
        }
    }
}

struct TireLifecycleChart: View {
    let dataPoints: [ChartDataPoint] = [
        ChartDataPoint(distance: 5, depth: 10.0),
        ChartDataPoint(distance: 10, depth: 7.0),
        ChartDataPoint(distance: 15, depth: 4.5),
        ChartDataPoint(distance: 20, depth: 2.8),
        ChartDataPoint(distance: 25, depth: 1.0)
    ]
    
    var body: some View {
        Chart(dataPoints, id: \.distance) { point in
            LineMark(
                x: .value("Distance", point.distance),
                y: .value("Tread Depth", point.depth)
            )
            .foregroundStyle(.cyan)
            .lineStyle(StrokeStyle(lineWidth: 3))
            
            PointMark(
                x: .value("Distance", point.distance),
                y: .value("Tread Depth", point.depth)
            )
            .foregroundStyle(.cyan)
            .symbolSize(60)
        }
        .chartXScale(domain: 0...25)
        .chartYScale(domain: 0...12)
        .chartXAxis {
            AxisMarks(values: [5, 10, 15, 20, 25]) { value in
                AxisGridLine()
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)K")
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 2.5, 5.0, 7.5, 10]) { value in
                AxisGridLine()
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "%.1f", doubleValue))
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                    }
                }
            }
        }
        .chartXAxisLabel("Distance (km)", alignment: .center)
        .chartYAxisLabel("Tread Depth (mm)", alignment: .center)
        .foregroundColor(.white)
        .background(Color.black)
    }
}

struct ChartDataPoint {
    let distance: Int
    let depth: Double
}

struct TireDimensionRow: View {
    let label: String
    let dimension: String
    let isRecommended: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 100, alignment: .leading)
            
            Text(dimension)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            if isRecommended {
                Spacer()
                Text("Recommended")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(12)
            }
            
            Spacer()
        }
    }
}

struct TireConditionIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.8))
                .frame(width: 50, height: 50)
            
            // Simplified tire icon
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .frame(width: 32, height: 32)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray)
                .frame(width: 20, height: 20)
        }
    }
}

struct TireConditionBar: View {
    let position: String
    let percentage: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(color)
                .frame(width: 20, height: CGFloat(percentage))
                .cornerRadius(4)
                .frame(height: 80, alignment: .bottom)
            
            Text("\(percentage)%")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
            
            Text(position)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
    }


    struct TyreDetailView: View {
        @State private var selectedTyre = "FL"
        
        var body: some View {
            NavigationView {
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header with car info
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Make")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("Toyota")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("Model")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("Camry SE")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("Season")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("Winter")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("DOT")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("1A2B 0323")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            
                            // Tyre visual representation
                            HStack {
                                Spacer()
                                TyreVisualizationView()
                                    .frame(width: 200, height: 200)
                                Spacer()
                            }
                            .padding(.vertical, 20)
                            
                            // Tread depth measurements
                            VStack(spacing: 20) {
                                HStack(spacing: 40) {
                                    TreadDepthCard(
                                        position: "FL",
                                        depth: "7.2 mm",
                                        progress: 0.9,
                                        color: .green
                                    )
                                    
                                    TreadDepthCard(
                                        position: "FR",
                                        depth: "7.2 mm",
                                        progress: 0.9,
                                        color: .green
                                    )
                                }
                                
                                HStack(spacing: 40) {
                                    TreadDepthCard(
                                        position: "RL",
                                        depth: "4.0 mm",
                                        progress: 0.5,
                                        color: .orange
                                    )
                                    
                                    TreadDepthCard(
                                        position: "RR",
                                        depth: "2.5 mm",
                                        progress: 0.25,
                                        color: .red
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Remaining life
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Remaining Life")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("80%")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                
                                ProgressView(value: 0.8)
                                    .progressViewStyle(CustomProgressViewStyle(color: .cyan))
                                    .frame(height: 8)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 30)
                            
                            // Tire Lifecycle Chart
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Text("Tire Lifecycle")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                
                                TireLifecycleChart()
                                    .frame(height: 200)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 30)
                            
                            // Compatible Tire Dimensions
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Text("Compatible Tire Dimensions")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                
                                VStack(spacing: 12) {
                                    TireDimensionRow(
                                        label: "Standard:",
                                        dimension: "255/50 R19 107W",
                                        isRecommended: true
                                    )
                                    
                                    TireDimensionRow(
                                        label: "Alternative:",
                                        dimension: "285/45 R19 111W",
                                        isRecommended: false
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 30)
                            
                            // Tire Condition
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Text("Tire Condition")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                
                                HStack(spacing: 20) {
                                    TireConditionIcon()
                                    
                                    HStack(spacing: 25) {
                                        TireConditionBar(position: "FL", percentage: 70, color: .green)
                                        TireConditionBar(position: "FR", percentage: 80, color: .green)
                                        TireConditionBar(position: "RL", percentage: 30, color: .orange)
                                        TireConditionBar(position: "RR", percentage: 35, color: .red)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 30)
                            .padding(.bottom, 40)
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .medium))
                        }
                    }
                    
                    ToolbarItem(placement: .principal) {
                        Text("Tyre Name")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {}) {
                            Image(systemName: "arrow.r.to.line")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .medium))
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    struct TyreVisualizationView: View {
        var body: some View {
            ZStack {
                // Main tire circle
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 180, height: 180)
                
                // Inner rim
                Circle()
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 120, height: 120)
                
                // Rim spokes
                ForEach(0..<6) { spoke in
                    Rectangle()
                        .fill(Color.gray.opacity(0.8))
                        .frame(width: 4, height: 40)
                        .offset(y: -20)
                        .rotationEffect(.degrees(Double(spoke) * 60))
                }
                
                // Center hub
                Circle()
                    .fill(Color.gray.opacity(0.9))
                    .frame(width: 30, height: 30)
            }
        }
    }

    struct TreadDepthCard: View {
        let position: String
        let depth: String
        let progress: Double
        let color: Color
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tread Depth")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    Spacer()
                    Text(position)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(depth)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                ProgressView(value: progress)
                    .progressViewStyle(CustomProgressViewStyle(color: color))
                    .frame(height: 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    struct CustomProgressViewStyle: ProgressViewStyle {
        let color: Color
        
        func makeBody(configuration: Configuration) -> some View {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0), height: 6)
                        .cornerRadius(3)
                }
            }
        }
    }

    struct TireLifecycleChart: View {
        let dataPoints: [ChartDataPoint] = [
            ChartDataPoint(distance: 5, depth: 10.0),
            ChartDataPoint(distance: 10, depth: 7.0),
            ChartDataPoint(distance: 15, depth: 4.5),
            ChartDataPoint(distance: 20, depth: 2.8),
            ChartDataPoint(distance: 25, depth: 1.0)
        ]
        
        var body: some View {
            Chart(dataPoints, id: \.distance) { point in
                LineMark(
                    x: .value("Distance", point.distance),
                    y: .value("Tread Depth", point.depth)
                )
                .foregroundStyle(.cyan)
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                PointMark(
                    x: .value("Distance", point.distance),
                    y: .value("Tread Depth", point.depth)
                )
                .foregroundStyle(.cyan)
                .symbolSize(60)
            }
            .chartXScale(domain: 0...25)
            .chartYScale(domain: 0...12)
            .chartXAxis {
                AxisMarks(values: [5, 10, 15, 20, 25]) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)K")
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 2.5, 5.0, 7.5, 10]) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(String(format: "%.1f", doubleValue))
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                        }
                    }
                }
            }
            .chartXAxisLabel("Distance (km)", alignment: .center)
            .chartYAxisLabel("Tread Depth (mm)", alignment: .center)
            .foregroundColor(.white)
            .background(Color.customBackgroundColor)
        }
    }

    struct ChartDataPoint {
        let distance: Int
        let depth: Double
    }

    struct TireDimensionRow: View {
        let label: String
        let dimension: String
        let isRecommended: Bool
        
        var body: some View {
            HStack {
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 100, alignment: .leading)
                
                Text(dimension)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                if isRecommended {
                    Spacer()
                    Text("Recommended")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(12)
                }
                
                Spacer()
            }
        }
    }

    struct TireConditionIcon: View {
        var body: some View {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.8))
                    .frame(width: 50, height: 50)
                
                // Simplified tire icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .frame(width: 32, height: 32)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray)
                    .frame(width: 20, height: 20)
            }
        }
    }

    struct TireConditionBar: View {
        let position: String
        let percentage: Int
        let color: Color
        
        var body: some View {
            VStack(spacing: 8) {
                Rectangle()
                    .fill(color)
                    .frame(width: 20, height: CGFloat(percentage))
                    .cornerRadius(4)
                    .frame(height: 80, alignment: .bottom)
                
                Text("\(percentage)%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
                
                Text(position)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    TyreDetailView()
}
