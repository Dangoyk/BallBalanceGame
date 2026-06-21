import SwiftUI
import SpriteKit

struct ContentView: View {

    @State private var scene: GameScene = {
        let s = GameScene()
        s.scaleMode = .resizeFill
        s.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return s
    }()

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .statusBar(hidden: true)
    }
}
