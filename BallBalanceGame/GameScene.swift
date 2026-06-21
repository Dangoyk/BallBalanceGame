import SpriteKit
import CoreMotion

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Properties

    private var ball: SKShapeNode!
    private var safeTop: CGFloat = 60
    private let motionManager = CMMotionManager()

    // HUD labels
    private var scoreLabel: SKLabelNode!
    private var livesLabel: SKLabelNode!
    private var coinLabel: SKLabelNode!
    private var windLabel: SKLabelNode!

    // Game state
    private var score: Int = 0
    private var lives: Int = 3
    private var coinsCollected: Int = 0
    private var isGameOver = false
    private var isInvincible = false
    private var gameStartTime: TimeInterval = 0

    // Timers
    private var lastHoleTime: TimeInterval = 0
    private var holeInterval: TimeInterval = 4.0
    private var lastCoinTime: TimeInterval = 0
    private var windChangeTimer: TimeInterval = 0
    private var windInterval: TimeInterval = 6.0

    // Wind
    private var windForce: CGVector = .zero

    // Physics categories
    private let ballCategory: UInt32 = 0x1 << 0
    private let wallCategory: UInt32 = 0x1 << 1
    private let holeCategory: UInt32 = 0x1 << 2
    private let coinCategory: UInt32 = 0x1 << 3

    private let ballRadius: CGFloat = 18

    private var highScore: Int {
        get { UserDefaults.standard.integer(forKey: "BallBalanceHighScore") }
        set { UserDefaults.standard.set(newValue, forKey: "BallBalanceHighScore") }
    }

    #if targetEnvironment(simulator)
    private var simulatorForce: CGVector = .zero
    #endif

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        safeTop = max(54, view.safeAreaInsets.top)
        setupScene()
        setupBoard()
        setupBall()
        setupHUD()
        setupInstructions()
        startMotion()
        changeWind()
    }

    // MARK: - Setup

    private func setupScene() {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        backgroundColor = SKColor(red: 0.07, green: 0.09, blue: 0.15, alpha: 1)
    }

    private func setupBoard() {
        let screenRect = CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        )

        let wallBody = SKPhysicsBody(edgeLoopFrom: screenRect)
        wallBody.categoryBitMask = wallCategory
        wallBody.friction = 0.05
        wallBody.restitution = 0.65

        // Invisible wall node just to hold the physics body
        let walls = SKNode()
        walls.physicsBody = wallBody
        walls.zPosition = 0
        addChild(walls)
    }

    private func setupBall() {
        ball = SKShapeNode(circleOfRadius: ballRadius)
        ball.fillColor = .white
        ball.strokeColor = SKColor(white: 0.88, alpha: 1)
        ball.lineWidth = 1.5
        ball.position = .zero
        ball.zPosition = 5

        let shine = SKShapeNode(circleOfRadius: ballRadius * 0.28)
        shine.fillColor = SKColor(white: 1, alpha: 0.72)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -ballRadius * 0.28, y: ballRadius * 0.28)
        shine.zPosition = 1
        ball.addChild(shine)

        let body = SKPhysicsBody(circleOfRadius: ballRadius)
        body.categoryBitMask = ballCategory
        body.contactTestBitMask = holeCategory | coinCategory
        body.collisionBitMask = wallCategory
        body.restitution = 0.4
        body.friction = 0.12
        body.linearDamping = 0.42
        body.angularDamping = 1.0
        body.allowsRotation = false
        ball.physicsBody = body

        addChild(ball)
    }

    private func setupHUD() {
        let hudH = safeTop + 88

        // Semi-transparent strip behind HUD so it's readable over the board
        let hudBg = SKShapeNode(rect: CGRect(
            x: -size.width / 2,
            y: size.height / 2 - hudH,
            width: size.width,
            height: hudH
        ))
        hudBg.fillColor = SKColor(white: 0, alpha: 0.52)
        hudBg.strokeColor = SKColor(red: 0.22, green: 0.42, blue: 0.88, alpha: 0.30)
        hudBg.lineWidth = 1
        hudBg.zPosition = 9
        addChild(hudBg)

        let row1Y = size.height / 2 - safeTop - 24
        let row2Y = size.height / 2 - safeTop - 58

        // Score — left
        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLabel.text = "0s"
        scoreLabel.fontSize = 30
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: -size.width / 4, y: row1Y)
        scoreLabel.zPosition = 10
        addChild(scoreLabel)

        // Coins — right
        coinLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        coinLabel.text = "● 0"
        coinLabel.fontSize = 24
        coinLabel.fontColor = SKColor(red: 1, green: 0.82, blue: 0.10, alpha: 1)
        coinLabel.horizontalAlignmentMode = .center
        coinLabel.position = CGPoint(x: size.width / 4, y: row1Y)
        coinLabel.zPosition = 10
        addChild(coinLabel)

        // Lives — left
        livesLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        livesLabel.fontSize = 18
        livesLabel.fontColor = SKColor(red: 1, green: 0.28, blue: 0.28, alpha: 1)
        livesLabel.horizontalAlignmentMode = .center
        livesLabel.position = CGPoint(x: -size.width / 4, y: row2Y)
        livesLabel.zPosition = 10
        updateLivesDisplay()
        addChild(livesLabel)

        // Wind — right
        windLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        windLabel.text = "CALM"
        windLabel.fontSize = 16
        windLabel.fontColor = SKColor(white: 0.50, alpha: 0.9)
        windLabel.horizontalAlignmentMode = .center
        windLabel.position = CGPoint(x: size.width / 4, y: row2Y)
        windLabel.zPosition = 10
        addChild(windLabel)
    }

    private func setupInstructions() {
        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = "Tilt to balance!"
        label.fontSize = 20
        label.fontColor = SKColor(white: 1, alpha: 0.65)
        label.position = CGPoint(x: 0, y: -60)
        label.zPosition = 6
        addChild(label)
        label.run(.sequence([
            .wait(forDuration: 2.5),
            .fadeOut(withDuration: 1.0),
            .removeFromParent()
        ]))
    }

    private func updateLivesDisplay() {
        livesLabel.text = (0..<3).map { $0 < lives ? "●" : "○" }.joined(separator: "  ")
    }

    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates()
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver else { return }

        if gameStartTime == 0 {
            gameStartTime = currentTime
            lastHoleTime = currentTime
            lastCoinTime = currentTime
            windChangeTimer = currentTime
        }

        score = Int(currentTime - gameStartTime)
        scoreLabel.text = "\(score)s"

        applyMotion()

        if currentTime - lastHoleTime > holeInterval {
            spawnHole()
            lastHoleTime = currentTime
            holeInterval = max(1.4, holeInterval - 0.15)
        }

        let ci = max(2.0, 3.5 - Double(score) / 120.0)
        if currentTime - lastCoinTime > ci {
            spawnCoin()
            lastCoinTime = currentTime
        }

        if currentTime - windChangeTimer > windInterval {
            changeWind()
            windChangeTimer = currentTime
        }
    }

    private func applyMotion() {
        var dx = windForce.dx
        var dy = windForce.dy
        #if targetEnvironment(simulator)
        dx += simulatorForce.dx
        dy += simulatorForce.dy
        #else
        if let motion = motionManager.deviceMotion {
            dx += CGFloat(motion.gravity.x) * 68
            dy += CGFloat(motion.gravity.y) * 68
        }
        #endif
        ball.physicsBody?.applyForce(CGVector(dx: dx, dy: dy))
    }

    // MARK: - Holes

    private func spawnHole() {
        let margin: CGFloat = 48
        let progress = min(1.0, CGFloat(score) / 60.0)
        let finalRadius = CGFloat.random(in: (15 + progress * 10)...(25 + progress * 16))

        let position = safeRandomPosition(margin: margin, avoidRadius: finalRadius * 4)

        let hole = SKShapeNode(circleOfRadius: finalRadius)
        hole.fillColor = .black
        hole.strokeColor = SKColor(red: 0.85, green: 0.10, blue: 0.10, alpha: 0.9)
        hole.lineWidth = 2.5
        hole.position = position
        hole.zPosition = 3
        hole.name = "hole"
        hole.setScale(0)
        addChild(hole)

        hole.run(.scale(to: 1, duration: 1.15)) { [weak self, weak hole] in
            guard let self, let hole, !self.isGameOver else { return }
            let body = SKPhysicsBody(circleOfRadius: finalRadius)
            body.isDynamic = false
            body.categoryBitMask = self.holeCategory
            body.contactTestBitMask = self.ballCategory
            body.collisionBitMask = 0
            hole.physicsBody = body
        }
    }

    // MARK: - Coins

    private func spawnCoin() {
        let margin: CGFloat = 44
        let radius: CGFloat = 11
        let position = safeRandomPosition(margin: margin, avoidRadius: 60)

        let coin = SKShapeNode(circleOfRadius: radius)
        coin.fillColor = SKColor(red: 1, green: 0.82, blue: 0.10, alpha: 1)
        coin.strokeColor = SKColor(red: 0.88, green: 0.62, blue: 0, alpha: 1)
        coin.lineWidth = 2
        coin.position = position
        coin.zPosition = 4
        coin.name = "coin"
        coin.setScale(0)

        let shine = SKShapeNode(circleOfRadius: radius * 0.3)
        shine.fillColor = SKColor(white: 1, alpha: 0.65)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -radius * 0.3, y: radius * 0.3)
        shine.zPosition = 1
        coin.addChild(shine)

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = false
        body.categoryBitMask = coinCategory
        body.contactTestBitMask = ballCategory
        body.collisionBitMask = 0
        coin.physicsBody = body

        addChild(coin)

        coin.run(.sequence([
            .scale(to: 1, duration: 0.22),
            .repeatForever(.sequence([
                .scale(to: 1.1, duration: 0.5),
                .scale(to: 1.0, duration: 0.5)
            ]))
        ]), withKey: "pulse")

        coin.run(.sequence([
            .wait(forDuration: 7.5),
            .run { [weak coin] in coin?.removeAction(forKey: "pulse") },
            .fadeOut(withDuration: 0.5),
            .removeFromParent()
        ]), withKey: "autoRemove")
    }

    private func collectCoin(_ node: SKNode) {
        guard node.physicsBody != nil else { return }
        node.physicsBody = nil
        node.removeAllActions()

        coinsCollected += 1
        coinLabel.text = "● \(coinsCollected)"
        SoundManager.shared.play(.coin)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        node.run(.sequence([
            .group([
                .scale(to: 1.7, duration: 0.12),
                .fadeOut(withDuration: 0.14)
            ]),
            .removeFromParent()
        ]))
    }

    // MARK: - Wind

    private func changeWind() {
        if Double.random(in: 0...1) < 0.22 {
            windForce = .zero
        } else {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let strength = CGFloat.random(in: 12...38)
            windForce = CGVector(dx: cos(angle) * strength, dy: sin(angle) * strength)
            SoundManager.shared.play(.wind)
        }
        windInterval = Double.random(in: 5...9)
        updateWindDisplay()
    }

    private func updateWindDisplay() {
        let strength = hypot(windForce.dx, windForce.dy)
        if strength < 4 {
            windLabel.text = "CALM"
            windLabel.fontColor = SKColor(white: 0.45, alpha: 0.9)
        } else {
            let arrow = windArrow(for: windForce)
            let word = strength < 24 ? "WIND" : "GUST"
            windLabel.text = "\(arrow) \(word)"
            windLabel.fontColor = strength < 24
                ? SKColor(red: 0.42, green: 0.80, blue: 1, alpha: 1)
                : SKColor(red: 1, green: 0.55, blue: 0.15, alpha: 1)
        }
    }

    private func windArrow(for force: CGVector) -> String {
        let deg = (atan2(Double(force.dy), Double(force.dx)) * 180 / .pi + 360)
            .truncatingRemainder(dividingBy: 360)
        switch deg {
        case 337.5..<360, 0..<22.5: return "→"
        case 22.5..<67.5:            return "↗"
        case 67.5..<112.5:           return "↑"
        case 112.5..<157.5:          return "↖"
        case 157.5..<202.5:          return "←"
        case 202.5..<247.5:          return "↙"
        case 247.5..<292.5:          return "↓"
        default:                      return "↘"
        }
    }

    // MARK: - Helpers

    private func safeRandomPosition(margin: CGFloat, avoidRadius: CGFloat) -> CGPoint {
        var best = randomBoardPosition(margin: margin)
        for _ in 0..<12 {
            let c = randomBoardPosition(margin: margin)
            if hypot(c.x - ball.position.x, c.y - ball.position.y) > avoidRadius {
                best = c
                break
            }
        }
        return best
    }

    private func randomBoardPosition(margin: CGFloat) -> CGPoint {
        let hudH = safeTop + 100
        let minX = -size.width / 2 + margin
        let maxX = size.width / 2 - margin
        let minY = -size.height / 2 + margin
        let maxY = size.height / 2 - hudH - margin
        guard minX < maxX, minY < maxY else { return .zero }
        return CGPoint(
            x: CGFloat.random(in: minX...maxX),
            y: CGFloat.random(in: minY...maxY)
        )
    }

    // MARK: - Physics Contact

    func didBegin(_ contact: SKPhysicsContact) {
        guard !isGameOver else { return }

        let a = contact.bodyA, b = contact.bodyB

        if a.categoryBitMask == coinCategory || b.categoryBitMask == coinCategory {
            let coinBody = a.categoryBitMask == coinCategory ? a : b
            if let node = coinBody.node { collectCoin(node) }
            return
        }

        guard !isInvincible else { return }
        if a.categoryBitMask == holeCategory || b.categoryBitMask == holeCategory {
            ballFellInHole()
        }
    }

    // MARK: - Ball Events

    private func ballFellInHole() {
        lives -= 1
        updateLivesDisplay()
        SoundManager.shared.play(.hole)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        if lives <= 0 {
            triggerGameOver()
            return
        }

        isInvincible = true
        ball.physicsBody?.velocity = .zero
        ball.physicsBody?.angularVelocity = 0
        ball.position = .zero

        let flash = SKAction.repeat(.sequence([
            .run { [weak self] in self?.ball.alpha = 0.20 },
            .wait(forDuration: 0.11),
            .run { [weak self] in self?.ball.alpha = 1.0 },
            .wait(forDuration: 0.11)
        ]), count: 7)

        ball.run(flash) { [weak self] in
            self?.isInvincible = false
        }
    }

    // MARK: - Game Over

    private func triggerGameOver() {
        isGameOver = true
        motionManager.stopDeviceMotionUpdates()
        ball.physicsBody?.isDynamic = false
        SoundManager.shared.play(.gameOver)
        UINotificationFeedbackGenerator().notificationOccurred(.error)

        let prevBest = highScore
        let isNewBest = score > prevBest
        if isNewBest { highScore = score }

        let overlay = SKShapeNode(rect: CGRect(
            x: -size.width / 2, y: -size.height / 2,
            width: size.width, height: size.height
        ))
        overlay.fillColor = SKColor(white: 0, alpha: 0.76)
        overlay.strokeColor = .clear
        overlay.zPosition = 20
        addChild(overlay)

        addGameOverLabel("GAME OVER",    fontSize: 52, color: .white,                                              y: 115)
        addGameOverLabel("Survived  \(score)s", fontSize: 30,
                         color: SKColor(red: 0.35, green: 0.78, blue: 1, alpha: 1),                               y: 60)
        addGameOverLabel("● \(coinsCollected) coins", fontSize: 22,
                         color: SKColor(red: 1, green: 0.82, blue: 0.10, alpha: 1),                               y: 22)

        if isNewBest {
            addGameOverLabel("NEW BEST!", fontSize: 22,
                             color: SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1),                            y: -14)
        } else if prevBest > 0 {
            addGameOverLabel("Best: \(prevBest)s", fontSize: 18,
                             color: SKColor(white: 0.55, alpha: 1),                                               y: -14)
        }

        let button = SKShapeNode(rectOf: CGSize(width: 224, height: 58), cornerRadius: 29)
        button.fillColor = SKColor(red: 0.22, green: 0.42, blue: 0.88, alpha: 1)
        button.strokeColor = .clear
        button.position = CGPoint(x: 0, y: -68)
        button.zPosition = 21
        button.name = "restart"

        let btnLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        btnLabel.text = "Play Again"
        btnLabel.fontSize = 26
        btnLabel.fontColor = .white
        btnLabel.verticalAlignmentMode = .center
        btnLabel.name = "restart"
        button.addChild(btnLabel)
        addChild(button)
    }

    @discardableResult
    private func addGameOverLabel(_ text: String, fontSize: CGFloat, color: SKColor, y: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.position = CGPoint(x: 0, y: y)
        label.zPosition = 21
        addChild(label)
        return label
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isGameOver {
            handleRestartTouch(touches)
            return
        }
        #if targetEnvironment(simulator)
        updateSimulatorForce(touches)
        #endif
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        #if targetEnvironment(simulator)
        if !isGameOver { updateSimulatorForce(touches) }
        #endif
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        #if targetEnvironment(simulator)
        simulatorForce = .zero
        #endif
    }

    private func handleRestartTouch(_ touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        if nodes(at: touch.location(in: self)).contains(where: { $0.name == "restart" }) {
            let newScene = GameScene(size: size)
            newScene.scaleMode = scaleMode
            newScene.anchorPoint = anchorPoint
            view?.presentScene(newScene, transition: .fade(withDuration: 0.4))
        }
    }

    #if targetEnvironment(simulator)
    private func updateSimulatorForce(_ touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        simulatorForce = CGVector(
            dx: (loc.x / (size.width / 2)) * 68,
            dy: (loc.y / (size.height / 2)) * 68
        )
    }
    #endif

    // MARK: - Cleanup

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
