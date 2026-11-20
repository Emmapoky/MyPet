import SwiftUI
import WidgetKit

// MyPet quick-log widgets: home screen (small, medium) and lock screen.
// On a free Apple account there are no App Groups, so the widget can't read the app's
// pets. It shows a fixed prompt and every tap opens the app's short form
// (mypet://app/log), where "All normal" is one tap. It never logs by itself.

private let logURL = URL(string: "mypet://app/log")!

struct QuickLogEntry: TimelineEntry {
  let date: Date
}

struct QuickLogProvider: TimelineProvider {
  func placeholder(in context: Context) -> QuickLogEntry { QuickLogEntry(date: .now) }
  func getSnapshot(in context: Context, completion: @escaping (QuickLogEntry) -> Void) {
    completion(QuickLogEntry(date: .now))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<QuickLogEntry>) -> Void) {
    completion(Timeline(entries: [QuickLogEntry(date: .now)], policy: .never))
  }
}

// Brand gradient (Tokens heroGradient) and text colours from the app theme.
private let brand = Color(red: 0x6A / 255, green: 0x4F / 255, blue: 0xD6 / 255)
private let brandEnd = Color(red: 0xB5 / 255, green: 0x48 / 255, blue: 0x8A / 255)
private let hero = LinearGradient(colors: [brand, brandEnd], startPoint: .topLeading, endPoint: .bottomTrailing)

struct QuickLogView: View {
  @Environment(\.widgetFamily) var family
  let entry: QuickLogEntry

  var body: some View {
    switch family {
    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        Image(systemName: "pawprint.fill").font(.title2)
      }
      .widgetURL(logURL)
      .accessibilityLabel("Log today in MyPet")
    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 2) {
        Label("MyPet", systemImage: "pawprint.fill").font(.headline)
        Text("How was today? Tap to log").font(.caption)
      }
      .widgetURL(logURL)
    case .accessoryInline:
      Label("Log today", systemImage: "pawprint.fill").widgetURL(logURL)
    case .systemMedium:
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Label("MyPet", systemImage: "pawprint.fill").font(.caption.bold()).foregroundStyle(.white.opacity(0.9))
          Text("How was today?").font(.title3.bold()).foregroundStyle(.white)
          Text("Ate, energy, toileting").font(.caption).foregroundStyle(.white.opacity(0.9))
        }
        Spacer(minLength: 0)
        VStack(spacing: 8) {
          Link(destination: logURL) {
            Label("All normal", systemImage: "checkmark.circle.fill")
              .font(.subheadline.bold()).foregroundStyle(brand)
              .frame(maxWidth: .infinity, minHeight: 44)
              .background(.white, in: RoundedRectangle(cornerRadius: 14))
          }
          Link(destination: logURL) {
            Text("Something's different")
              .font(.caption.bold()).foregroundStyle(.white)
              .frame(maxWidth: .infinity, minHeight: 44)
              .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.8)))
          }
        }
        .frame(width: 150)
      }
      .containerBackground(for: .widget) { hero }
    default:
      VStack(alignment: .leading, spacing: 6) {
        Image(systemName: "pawprint.fill").font(.title2).foregroundStyle(.white)
        Spacer(minLength: 0)
        Text("How was today?").font(.headline).foregroundStyle(.white)
        Text("Tap to log").font(.caption).foregroundStyle(.white.opacity(0.9))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .widgetURL(logURL)
      .containerBackground(for: .widget) { hero }
    }
  }
}

struct MyPetQuickLogWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "MyPetQuickLog", provider: QuickLogProvider()) { entry in
      QuickLogView(entry: entry)
    }
    .configurationDisplayName("Quick log")
    .description("Log your pet's day in a tap.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
  }
}

@main
struct MyPetWidgetBundle: WidgetBundle {
  var body: some Widget {
    MyPetQuickLogWidget()
  }
}
