//
//  HeatMapView.swift
//  TyreVibes
//
//  Advanced heat map visualization for tyre depth analysis
//

import SwiftUI

// MARK: - Heat Map View
struct HeatMapView: View {
    let heatMap: DepthHeatMap
    let minDepth: Double
    let maxDepth: Double
    @State private var selectedCell: (row: Int, col: Int)?
    @State private var showLegend: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            // Title
            HStack {
                Text("Depth Heat Map")
                    .font(.customFont(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { showLegend.toggle() }) {
                    Image(systemName: showLegend ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)

            // Heat Map Grid
            GeometryReader { geometry in
                let cellWidth = geometry.size.width / CGFloat(heatMap.gridSize.columns)
                let cellHeight = geometry.size.height / CGFloat(heatMap.gridSize.rows)

                ZStack {
                    // Grid cells
                    ForEach(0..<heatMap.gridSize.rows, id: \.self) { row in
                        ForEach(0..<heatMap.gridSize.columns, id: \.self) { col in
                            let depth = heatMap.dataPoints[row][col]
                            let color = heatMap.colorForDepth(depth, minDepth: minDepth, maxDepth: maxDepth)

                            Rectangle()
                                .fill(color)
                                .frame(
                                    width: cellWidth - 2,
                                    height: cellHeight - 2
                                )
                                .position(
                                    x: CGFloat(col) * cellWidth + cellWidth / 2,
                                    y: CGFloat(row) * cellHeight + cellHeight / 2
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(
                                            selectedCell?.row == row && selectedCell?.col == col
                                                ? Color.white
                                                : Color.clear,
                                            lineWidth: 3
                                        )
                                        .frame(
                                            width: cellWidth - 2,
                                            height: cellHeight - 2
                                        )
                                        .position(
                                            x: CGFloat(col) * cellWidth + cellWidth / 2,
                                            y: CGFloat(row) * cellHeight + cellHeight / 2
                                        )
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if selectedCell?.row == row && selectedCell?.col == col {
                                            selectedCell = nil
                                        } else {
                                            selectedCell = (row, col)
                                        }
                                    }
                                }
                        }
                    }

                    // Overlay selected cell value
                    if let selected = selectedCell {
                        let depth = heatMap.dataPoints[selected.row][selected.col]
                        let x = CGFloat(selected.col) * cellWidth + cellWidth / 2
                        let y = CGFloat(selected.row) * cellHeight + cellHeight / 2

                        VStack(spacing: 4) {
                            Text(String(format: "%.1f mm", depth))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Row \(selected.row), Col \(selected.col)")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.8))
                        )
                        .position(x: x, y: max(40, min(y, geometry.size.height - 40)))
                    }
                }
            }
            .aspectRatio(1.5, contentMode: .fit)
            .background(Color.black.opacity(0.2))
            .cornerRadius(12)

            // Legend
            if showLegend {
                HeatMapLegend(
                    colorScheme: heatMap.colorScheme,
                    minValue: minDepth,
                    maxValue: maxDepth
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Heat Map Legend
struct HeatMapLegend: View {
    let colorScheme: DepthHeatMap.HeatMapColorScheme
    let minValue: Double
    let maxValue: Double

    var body: some View {
        VStack(spacing: 8) {
            Text("Depth Scale (mm)")
                .font(.customFont(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: 0) {
                // Color gradient bar
                LinearGradient(
                    colors: colorScheme.colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 20)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            }

            // Min/Max labels
            HStack {
                Text(String(format: "%.1f", minValue))
                    .font(.customFont(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Text(String(format: "%.1f", (minValue + maxValue) / 2))
                    .font(.customFont(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Text(String(format: "%.1f", maxValue))
                    .font(.customFont(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
}

// MARK: - 3D-Style Heat Map (Advanced)
struct HeatMap3DView: View {
    let heatMap: DepthHeatMap
    let minDepth: Double
    let maxDepth: Double
    @State private var rotationAngle: Double = 0
    @State private var elevation: Double = 20

    var body: some View {
        VStack(spacing: 16) {
            Text("3D Depth Visualization")
                .font(.customFont(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            GeometryReader { geometry in
                Canvas { context, size in
                    let cellWidth = size.width / CGFloat(heatMap.gridSize.columns)
                    let cellHeight = size.height / CGFloat(heatMap.gridSize.rows)

                    for row in 0..<heatMap.gridSize.rows {
                        for col in 0..<heatMap.gridSize.columns {
                            let depth = heatMap.dataPoints[row][col]
                            let color = heatMap.colorForDepth(depth, minDepth: minDepth, maxDepth: maxDepth)

                            // Calculate 3D position
                            let x = CGFloat(col) * cellWidth
                            let y = CGFloat(row) * cellHeight

                            // Elevation based on depth
                            let normalizedDepth = (depth - minDepth) / (maxDepth - minDepth)
                            let z = normalizedDepth * elevation

                            // Apply pseudo-3D transformation
                            let transformedX = x + z * cos(rotationAngle * .pi / 180)
                            let transformedY = y - z * sin(rotationAngle * .pi / 180)

                            let rect = CGRect(
                                x: transformedX,
                                y: transformedY,
                                width: cellWidth - 2,
                                height: cellHeight - 2
                            )

                            context.fill(
                                Path(roundedRect: rect, cornerRadius: 2),
                                with: .color(color)
                            )

                            // Add highlight for depth
                            if normalizedDepth > 0.7 {
                                context.stroke(
                                    Path(roundedRect: rect, cornerRadius: 2),
                                    with: .color(.white.opacity(0.3)),
                                    lineWidth: 1
                                )
                            }
                        }
                    }
                }
            }
            .aspectRatio(1.5, contentMode: .fit)
            .background(Color.black.opacity(0.2))
            .cornerRadius(12)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        rotationAngle = Double(value.translation.width) / 2
                        elevation = 20 + Double(value.translation.height) / 10
                    }
            )

            Text("Drag to rotate and adjust elevation")
                .font(.customFont(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Interpolated Heat Map
struct InterpolatedHeatMapView: View {
    let measurements: [DepthMeasurementPoint]
    let gridSize: Int
    let minDepth: Double
    let maxDepth: Double

    private var heatMap: DepthHeatMap {
        generateInterpolatedHeatMap()
    }

    var body: some View {
        HeatMapView(
            heatMap: heatMap,
            minDepth: minDepth,
            maxDepth: maxDepth
        )
    }

    private func generateInterpolatedHeatMap() -> DepthHeatMap {
        var grid: [[Double]] = Array(
            repeating: Array(repeating: 0.0, count: gridSize),
            count: gridSize
        )

        // Interpolate depth values using inverse distance weighting
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let x = Double(col) / Double(gridSize - 1)
                let y = Double(row) / Double(gridSize - 1)

                let interpolatedDepth = inverseDistanceWeighting(
                    at: CGPoint(x: x, y: y),
                    from: measurements
                )

                grid[row][col] = interpolatedDepth
            }
        }

        return DepthHeatMap(
            gridSize: DepthHeatMap.GridSize(rows: gridSize, columns: gridSize),
            dataPoints: grid,
            colorScheme: .thermal,
            interpolated: true
        )
    }

    private func inverseDistanceWeighting(
        at point: CGPoint,
        from measurements: [DepthMeasurementPoint],
        power: Double = 2.0
    ) -> Double {
        var weightedSum = 0.0
        var weightSum = 0.0

        for measurement in measurements {
            let dx = point.x - measurement.x
            let dy = point.y - measurement.y
            let distance = sqrt(dx * dx + dy * dy)

            // Avoid division by zero
            if distance < 0.001 {
                return measurement.depth
            }

            let weight = 1.0 / pow(distance, power)
            weightedSum += weight * measurement.depth
            weightSum += weight
        }

        return weightSum > 0 ? weightedSum / weightSum : 0
    }
}

// MARK: - Heat Map Statistics Panel
struct HeatMapStatisticsPanel: View {
    let heatMap: DepthHeatMap
    let depthAnalysis: DepthAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                StatRow(label: "Average Depth", value: String(format: "%.2f mm", depthAnalysis.average))
                StatRow(label: "Minimum Depth", value: String(format: "%.2f mm", depthAnalysis.minimum))
                StatRow(label: "Maximum Depth", value: String(format: "%.2f mm", depthAnalysis.maximum))
                StatRow(label: "Std. Deviation", value: String(format: "%.2f mm", depthAnalysis.standardDeviation))
                StatRow(label: "Measurements", value: "\(depthAnalysis.measurements.count)")
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
            )
        }
        .padding(.horizontal, 20)
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.customFont(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Text(value)
                .font(.customFont(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}
