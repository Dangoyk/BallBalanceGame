import SpriteKit
import CoreMotion

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Properties

    private var ball: SKShapeNode!
    private var safeTop: CGFloat = 60
    private let motionManager = CMMotionManager()

    // HUD
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
    private var lastStreakTime: TimeInterval = 0
    private var lastTrailTime: TimeInterval = 0

    // Wind — split into current and pre-generated next
    private var windForce: CGVector = .zero
    private var nextWindForce: CGVector = .zero
    private var windChangeTimer: TimeInterval = 0
    private var windInterval: TimeInterval = 6.0
    private var windForecastShown = false

    // Physics categories
    private let ballCategory: UInt32 = 0x1 << 0
    private let holeCategory: UInt32 = 0x1 << 1
    private let coinCategory: UInt32 = 0x1 << 2

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
        setupBall()
        setupHUD()
        setupInstructions()
        startMotion()
        applyInitialWind()
    }

    // MARK: - Setup

    private func setupScene() {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        backgroundColor = SKColor(red: 0.07, green: 0.09, blue: 0.15, alpha: 1)
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
        body.collisionBitMask = 0   // No walls — ball can fall off the edge
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

        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLabel.text = "0s"
        scoreLabel.fontSize = 30
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: -size.width / 4, y: row1Y)
        scoreLabel.zPosition = 10
        addChild(scoreLabel)

        coinLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        coinLabel.text = "● 0"
        coinLabel.fontSize = 24
        coinLabel.fontColor = SKColor(red: 1, green: 0.82, blue: 0.10, alpha: 1)
        coinLabel.horizontalAlignmentMode = .center
        coinLabel.position = CGPoint(x: size.width / 4, y: row1Y)
        coinLabel.zPosition = 10
        addChild(coinLabel)

        livesLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        livesLabel.fontSize = 18
        livesLabel.fontColor = SKColor(red: 1, green: 0.28, blue: 0.28, alpha: 1)
        livesLabel.horizontalAlignmentMode = .center
        livesLabel.position = CGPoint(x: -size.width / 4, y: row2Y)
        livesLabel.zPosition = 10
        updateLivesDisplay()
        addChild(livesLabel)

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
            lastStreakTime = currentTime
            lastTrailTime = currentTime
        }

        score = Int(currentTime - gameStartTime)
        scoreLabel.text = "\(score)s"

        applyMotion()
        checkBallBounds()
        updateTrail(currentTime: currentTime)

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

        // Wind forecast: show 3s before the change
        if !windForecastShown && gameStartTime > 0 {
            let timeUntilChange = windInterval - (currentTime - windChangeTimer)
            if timeUntilChange <= 3.0 && timeUntilChange >= 0 {
                prepareNextWind()
                showWindForecast()
                windForecastShown = true
            }
        }

        // Apply prepared wind when timer expires
        if currentTime - windChangeTimer > windInterval {
            windForce = nextWindForce
            if hypot(windForce.dx, windForce.dy) > 4 { SoundManager.shared.play(.wind) }
            windInterval = Double.random(in: 5...9)
            windChangeTimer = currentTime
            windForecastShown = false
            updateWindDisplay()
        }

        let windSpeed = hypot(windForce.dx, windForce.dy)
        if windSpeed > 4 {
            let streakInterval = max(0.06, 0.22 - Double(windSpeed) / 120.0)
            if currentTime - lastStreakTime > streakInterval {
                spawnWindStreak()
                lastStreakTime = currentTime
            }
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

    // MARK: - Edge Detection

    private func checkBallBounds() {
        guard !isInvincible else { return }
        if abs(ball.position.x) > size.width / 2 || abs(ball.position.y) > size.height / 2 {
            ballFellInHole()
        }
    }

    // MARK: - Ball Trail

    private func updateTrail(currentTime: TimeInterval) {
        guard currentTime - lastTrailTime > 0.025 else { return }
        lastTrailTime = currentTime
        let velocity = ball.physicsBody?.velocity ?? .zero
        guard hypot(velocity.dx, velocity.dy) > 30 else { return }

        let r = CGFloat.random(in: 2.0...4.5)
        let particle = SKShapeNode(circleOfRadius: r)
        particle.fillColor = SKColor(white: 0.88, alpha: 0.55)
        particle.strokeColor = .clear
        particle.position = ball.position
        particle.zPosition = 4
        particle.name = "trail"
        addChild(particle)

        particle.run(.sequence([
            .group([.scale(to: 0.05, duration: 0.30), .fadeOut(withDuration: 0.30)]),
            .removeFromParent()
        ]))
    }

    // MARK: - Holes

    private func spawnHole() {
        let margin: CGFloat = 48
        let progress = min(1.0, CGFloat(score) / 60.0)
        let finalRadius = CGFloat.random(in: (15 + progress * 10)...(25 + progress * 16))

        let position = findSpawnPosition(
            margin: margin, minDistFromBall: finalRadius * 4,
            selfRadius: finalRadius, noOverlapWith: ["hole"]
        )

        let hole = SKShapeNode(circleOfRadius: finalRadius)
        hole.fillColor = .black
        hole.strokeColor = SKColor(red: 0.85, green: 0.10, blue: 0.10, alpha: 0.9)
        hole.lineWidth = 2.5
        hole.position = position
        hole.zPosition = 3
        hole.name = "hole"
        hole.userData = NSMutableDictionary(dictionary: ["radius": finalRadius])
        hole.alpha = 0
        addChild(hole)

        // Flicker warning, then solidify and become active
        let flicker = SKAction.repeat(.sequence([
            .fadeAlpha(to: 0.26, duration: 0.10),
            .fadeAlpha(to: 0.00, duration: 0.10)
        ]), count: 8)

        hole.run(.sequence([
            flicker,
            .fadeAlpha(to: 1.0, duration: 0.28),
            .run { [weak self, weak hole] in
                guard let self, let hole, !self.isGameOver else { return }
                let body = SKPhysicsBody(circleOfRadius: finalRadius)
                body.isDynamic = false
                body.categoryBitMask = self.holeCategory
                body.contactTestBitMask = self.ballCategory
                body.collisionBitMask = 0
                hole.physicsBody = body
            }
        ]))

        // Close after lifetime
        let lifetime = Double.random(in: 15...22)
        hole.run(.sequence([
            .wait(forDuration: lifetime),
            .run { [weak hole] in hole?.physicsBody = nil },
            .fadeOut(withDuration: 0.65),
            .removeFromParent()
        ]), withKey: "lifetime")
    }

    // MARK: - Coins

    private func spawnCoin() {
        let margin: CGFloat = 44
        let radius: CGFloat = 11

        let position = findSpawnPosition(
            margin: margin, minDistFromBall: 60,
            selfRadius: radius, noOverlapWith: ["hole", "coin"]
        )

        let coin = SKShapeNode(circleOfRadius: radius)
        coin.fillColor = SKColor(red: 1, green: 0.82, blue: 0.10, alpha: 1)
        coin.strokeColor = SKColor(red: 0.88, green: 0.62, blue: 0, alpha: 1)
        coin.lineWidth = 2
        coin.position = position
        coin.zPosition = 4
        coin.name = "coin"
        coin.userData = NSMutableDictionary(dictionary: ["radius": radius])
        coin.alpha = 0

        let shine = SKShapeNode(circleOfRadius: radius * 0.3)
        shine.fillColor = SKColor(white: 1, alpha: 0.65)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -radius * 0.3, y: radius * 0.3)
        shine.zPosition = 1
        coin.addChild(shine)

        addChild(coin)

        // Flicker warning, then appear and become collectible
        let flicker = SKAction.repeat(.sequence([
            .fadeAlpha(to: 0.35, duration: 0.09),
            .fadeAlpha(to: 0.00, duration: 0.09)
        ]), count: 5)

        coin.run(.sequence([
            flicker,
            .fadeAlpha(to: 1.0, duration: 0.18),
            .run { [weak coin] in
                guard let coin else { return }
                let body = SKPhysicsBody(circleOfRadius: radius)
                body.isDynamic = false
                body.categoryBitMask = self.coinCategory
                body.contactTestBitMask = self.ballCategory
                body.collisionBitMask = 0
                coin.physicsBody = body
            },
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

    private func applyInitialWind() {
        prepareNextWind()
        windForce = nextWindForce
        if hypot(windForce.dx, windForce.dy) > 4 { SoundManager.shared.play(.wind) }
        windInterval = Double.random(in: 5...9)
        windForecastShown = true   // Skip forecast for the starting wind
        updateWindDisplay()
    }

    private func prepareNextWind() {
        if Double.random(in: 0...1) < 0.22 {
            nextWindForce = .zero
        } else {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let strength = CGFloat.random(in: 6...18)
            nextWindForce = CGVector(dx: cos(angle) * strength, dy: sin(angle) * strength)
        }
    }

    private func updateWindDisplay() {
        let strength = hypot(windForce.dx, windForce.dy)
        if strength < 4 {
            windLabel.text = "CALM"
            windLabel.fontColor = SKColor(white: 0.45, alpha: 0.9)
        } else {
            let arrow = windArrow(for: windForce)
            let word = strength < 12 ? "WIND" : "GUST"
            windLabel.text = "\(arrow) \(word)"
            windLabel.fontColor = strength < 12
                ? SKColor(red: 0.42, green: 0.80, blue: 1, alpha: 1)
                : SKColor(red: 1, green: 0.55, blue: 0.15, alpha: 1)
        }
    }

    private func showWindForecast() {
        let strength = hypot(nextWindForce.dx, nextWindForce.dy)
        let isComing = strength > 4

        let panelH: CGFloat = 72
        let panelW = size.width * 0.72
        let hudBottom = size.height / 2 - (safeTop + 88)
        let panelCenterY = hudBottom - panelH / 2 - 12

        let accentColor: SKColor = !isComing
            ? SKColor(white: 0.50, alpha: 0.8)
            : strength < 12
                ? SKColor(red: 0.42, green: 0.80, blue: 1, alpha: 0.9)
                : SKColor(red: 1, green: 0.55, blue: 0.15, alpha: 0.95)

        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 14)
        panel.fillColor = SKColor(white: 0, alpha: 0.82)
        panel.strokeColor = accentColor
        panel.lineWidth = 1.5
        panel.position = CGPoint(x: 0, y: panelCenterY)
        panel.zPosition = 15
        panel.alpha = 0
        panel.name = "forecast"
        addChild(panel)

        let header = SKLabelNode(fontNamed: "AvenirNext-Medium")
        header.text = "WIND FORECAST"
        header.fontSize = 11
        header.fontColor = SKColor(white: 0.48, alpha: 1)
        header.position = CGPoint(x: 0, y: panelH / 2 - 18)
        header.zPosition = 1
        panel.addChild(header)

        let main = SKLabelNode(fontNamed: "AvenirNext-Bold")
        main.text = isComing ? "\(windArrow(for: nextWindForce))  \(strength < 12 ? "WIND" : "GUST")" : "CALM"
        main.fontSize = 28
        main.fontColor = accentColor
        main.verticalAlignmentMode = .center
        main.position = CGPoint(x: 0, y: -6)
        main.zPosition = 1
        panel.addChild(main)

        panel.run(.sequence([
            .fadeIn(withDuration: 0.28),
            .wait(forDuration: 2.1),
            .fadeOut(withDuration: 0.22),
            .removeFromParent()
        ]))
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

    private func spawnWindStreak() {
        let windAngle = atan2(windForce.dy, windForce.dx)
        let windSpeed = hypot(windForce.dx, windForce.dy)
        let perpAngle = windAngle + .pi / 2
        let screenDiag = hypot(size.width, size.height)
        let spread = CGFloat.random(in: -screenDiag / 2...screenDiag / 2)

        let startX = -cos(windAngle) * screenDiag * 0.65 + cos(perpAngle) * spread
        let startY = -sin(windAngle) * screenDiag * 0.65 + sin(perpAngle) * spread

        let length = CGFloat.random(in: 30...80)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -length / 2, y: 0))
        path.addLine(to: CGPoint(x: length / 2, y: 0))

        let streak = SKShapeNode(path: path)
        streak.strokeColor = SKColor(red: 0.62, green: 0.85, blue: 1, alpha: 0.9)
        streak.lineWidth = CGFloat.random(in: 0.5...1.8)
        streak.zRotation = windAngle
        streak.position = CGPoint(x: startX, y: startY)
        streak.zPosition = 7
        streak.alpha = 0
        addChild(streak)

        let travelDist = screenDiag * 1.4
        let duration = Double(travelDist) / Double(windSpeed * 50)
        let peakAlpha = CGFloat.random(in: 0.20...0.48)
        let fadeTime = min(0.10, duration * 0.18)
        let holdTime = max(0, duration - fadeTime * 2)

        streak.run(.sequence([
            .group([
                .moveBy(x: cos(windAngle) * travelDist, y: sin(windAngle) * travelDist, duration: duration),
                .sequence([
                    .fadeAlpha(to: peakAlpha, duration: fadeTime),
                    .wait(forDuration: holdTime),
                    .fadeAlpha(to: 0, duration: fadeTime)
                ])
            ]),
            .removeFromParent()
        ]))
    }

    // MARK: - Spawn Helpers

    private func findSpawnPosition(margin: CGFloat, minDistFromBall: CGFloat,
                                    selfRadius: CGFloat, noOverlapWith names: [String]) -> CGPoint {
        var best = randomBoardPosition(margin: margin)
        for _ in 0..<20 {
            let candidate = randomBoardPosition(margin: margin)
            let farEnough = hypot(candidate.x - ball.position.x,
                                  candidate.y - ball.position.y) > minDistFromBall
            if farEnough && !overlapsNode(at: candidate, radius: selfRadius, names: names) {
                return candidate
            }
            if farEnough { best = candidate }
        }
        return best
    }

    private func overlapsNode(at point: CGPoint, radius: CGFloat, names: [String]) -> Bool {
        for node in children {
            guard let name = node.name, names.contains(name),
                  let nodeRadius = node.userData?["radius"] as? CGFloat else { continue }
            if hypot(point.x - node.position.x, point.y - node.position.y) < radius + nodeRadius + 10 {
                return true
            }
        }
        return false
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

        addGameOverLabel("GAME OVER", fontSize: 52, color: .white, y: 115)
        addGameOverLabel("Survived  \(score)s", fontSize: 30,
                         color: SKColor(red: 0.35, green: 0.78, blue: 1, alpha: 1), y: 60)
        addGameOverLabel("● \(coinsCollected) coins", fontSize: 22,
                         color: SKColor(red: 1, green: 0.82, blue: 0.10, alpha: 1), y: 22)

        if isNewBest {
            addGameOverLabel("NEW BEST!", fontSize: 22,
                             color: SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1), y: -14)
        } else if prevBest > 0 {
            addGameOverLabel("Best: \(prevBest)s", fontSize: 18,
                             color: SKColor(white: 0.55, alpha: 1), y: -14)
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
