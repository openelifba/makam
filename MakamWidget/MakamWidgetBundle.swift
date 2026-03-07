// MARK: - MakamWidgetBundle.swift
// Makam — Widget extension entry point.
//
// This file is the *only* @main in the widget extension target.
// Additional widget kinds (e.g. a standalone countdown widget) can be
// added to the `@WidgetBundleBuilder` body without touching any other file.

import WidgetKit
import SwiftUI

@main
struct MakamWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        // Primary prayer-time widget (Small, Medium, Accessory Rectangular)
        MakamWidget()

        // Future: MakamCountdownWidget(), MakamQiblaWidget() …
    }
}
