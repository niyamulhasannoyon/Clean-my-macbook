import SwiftUI

struct ProcessMetric: Identifiable {
    let id = UUID()
    let name: String
    let cpuPercent: String
    let ramUsage: String
    let icon: String
}

struct PerformanceView: View {
    @State private var cpuLoad: Double = 0.24
    @State private var ramUsed: Double = 0.58
    
    let heavyProcesses: [ProcessMetric] = [
        ProcessMetric(name: "Xcode", cpuPercent: "14.2%", ramUsage: "3.4 GB", icon: "hammer.fill"),
        ProcessMetric(name: "WindowServer", cpuPercent: "8.1%", ramUsage: "780 MB", icon: "macwindow"),
        ProcessMetric(name: "Google Chrome Helper", cpuPercent: "6.5%", ramUsage: "1.2 GB", icon: "globe"),
        ProcessMetric(name: "Slack Helper", cpuPercent: "3.2%", ramUsage: "640 MB", icon: "bubble.left.and.bubble.right.fill"),
        ProcessMetric(name: "Terminal", cpuPercent: "1.1%", ramUsage: "120 MB", icon: "terminal.fill")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeaderBannerView(item: .performance, statusText: "Healthy", statusColor: .mint)
                
                // Hardware Gauge Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    VStack(spacing: 12) {
                        CircularProgressView(
                            progress: cpuLoad,
                            lineWidth: 8,
                            gradientColors: [.mint, .teal],
                            title: "CPU Load"
                        )
                        .frame(width: 90, height: 90)
                        
                        Text("Apple Silicon • 8 Cores")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                    )
                    
                    VStack(spacing: 12) {
                        CircularProgressView(
                            progress: ramUsed,
                            lineWidth: 8,
                            gradientColors: [.blue, .purple],
                            title: "RAM Usage"
                        )
                        .frame(width: 90, height: 90)
                        
                        Text("9.3 GB / 16 GB Used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                    )
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                            Text("Power & Thermals")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Battery Health: 98%")
                                .font(.caption.weight(.medium))
                            Text("Thermals: Nominal (36°C)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Fan Speed: Quiet (0 RPM)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                    )
                }
                
                // Heavy Consumers Table
                VStack(alignment: .leading, spacing: 10) {
                    Text("Top Resource Consumers")
                        .font(.headline)
                        .padding(.top, 4)
                    
                    VStack(spacing: 8) {
                        ForEach(heavyProcesses) { process in
                            HStack(spacing: 12) {
                                Image(systemName: process.icon)
                                    .frame(width: 24)
                                    .foregroundColor(.mint)
                                
                                Text(process.name)
                                    .font(.system(size: 13, weight: .medium))
                                
                                Spacer()
                                
                                Text("CPU: \(process.cpuPercent)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                                
                                Text("RAM: \(process.ramUsage)")
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                            )
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}
