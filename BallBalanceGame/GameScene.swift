import SpriteKit
import CoreMotion

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Properties

    private var ball: SKShapeNode!
    private var boardRect: CGRect = .zero
    private let motionManager = CMMotionManager()

    private var scoreLabel: SKLabelNode!
    private var livesLabel: SKLabelNode!

    private var score: Int = 0
    private var lives: Int = 3
    private var isGameOver = false
    private var isInvincible = false
    private var gameStartTime: TimeInterval = 0
    private var lastHoleTime: TimeInterval = 0
    private var holeInterval: TimeInterval = 4.0

    private let ballRadius: CGFloat = 18
    private let ballCategory: UInt32 = 0x1 << 0
    private let wallCategory: UInt32 = 0x1 << 1
    private let holeCategory: UInt32 = 0x1 << 2

    private var highScore: Int {
        get { UserDefaults.standard.integer(forKey: "BallBalanceHighScore") }
        set { UserDefaults.standard.set(newValue, forKey: "BallBalanceHighScore") }
    }

    #if targetEnvironment(simulator)
    private var simulatorForce: CGVector = .zero
    #endif

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        setupScene()
        setupBoard()
        setupBall()
        setupHUD()
        setupInstructions()
        startMotion()
    }

    // MARK: - Setup

    private func setupScene() {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        backgroundColor = .black
    }

    private func setupBoard() {
        let padding: CGFloat = 28
        let topPadding: CGFloat = 135
        boardRect = CGRect(
            x: -size.width / 2 + padding,
            y: -size.height / 2 + padding,
            width: size.width - padding * 2,
            height: size.height - padding - topPadding
        )

        let board = SKShapeNode(rect: boardRect, cornerRadius: 22)
        board.fillColor = SKColor(red: 0.07, green: 0.09, blue: 0.15, alpha: 1)
        board.strokeColor = SKColor(red: 0.22, green: 0.42, blue: 0.88, alpha: 1)
        board.lineWidth = 3
        board.zPosition = 0

        let wallBody = SKPhysicsBody(edgeLoopFrom: boardRect)
        wallBody.categoryBitMask = wallCategory
        wallBody.friction = 0.05
        wallBody.restitution = 0.65
        board.physicsBody = wallBody

        addChild(board)

        // Corner glow dots
        let corners: [CGPoint] = [
            CGPoint(x: boardRect.minX + 16, y: boardRect.minY + 16),
            CGPoint(x: boardRect.maxX - 16, y: boardRect.minY + 16),
            CGPoint(x: boardRect.minX + 16, y: boardRect.maxY - 16),
            CGPoint(x: boardRect.maxX - 16, y: boardRect.maxY - 16)
        ]
        for pt in corners {
            let dot = SKShapeNode(circleOfRadius: 4)
            dot.fillColor = SKColor(red: 0.22, green: 0.42, blue: 0.88, alpha: 0.6)
            dot.strokeColor = .clear
            dot.position = pt
            dot.zPosition = 1
            addChild(dot)
        }
    }

    private func setupBall() {
        ball = SKShapeNode(circleOfRadius: ballRadius)
        ball.fillColor = .white
        ball.strokeColor = SKColor(white: 0.88, alpha: 1)
        ball.lineWidth = 1.5
        ball.position = CGPoint(x: boardRect.midX, y: boardRect.midY)
        ball.zPosition = 5

        // Shine highlight
        let shine = SKShapeNode(circleOfRadius: ballRadius * 0.28)
        shine.fillColor = SKColor(white: 1, alpha: 0.72)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -ballRadius * 0.28, y: ballRadius * 0.28)
        shine.zPosition = 1
        ball.addChild(shine)

        let body = SKPhysicsBody(circleOfRadius: ballRadius)
        body.categoryBitMask = ballCategory
        body.contactTestBitMask = holeCategory
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
        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        titleLabel.text = "BALL BALANCE"
        titleLabel.fontSize = 18
        titleLabel.fontColor = SKColor(red: 0.22, green: 0.42, blue: 0.88, alpha: 0.85)
        titleLabel.position = CGPoint(x: 0, y: size.height / 2 - 52)
        titleLabel.zPosition = 10
        addChild(titleLabel)

        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLabel.text = "0s"
        scoreLabel.fontSize = 38
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: 0, y: size.height / 2 - 88)
        scoreLabel.zPosition = 10
        addChild(scoreLabel)

        livesLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        livesLabel.fontSize = 22
        livesLabel.fontColor = SKColor(red: 1, green: 0.28, blue: 0.28, alpha: 1)
        livesLabel.position = CGPoint(x: 0, y: size.height / 2 - 120)
        livesLabel.zPosition = 10
        updateLivesDisplay()
        addChild(livesLabel)
    }

    private func setupInstructions() {
        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = "Tilt to balance!"
        label.fontSize = 20
        label.fontColor = SKColor(white: 1, alpha: 0.65)
        label.position = CGPoint(x: boardRect.midX, y: boardRect.midY - 55)
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

        if gameStartTime == 0 { gameStartTime = currentTime }
        score = Int(currentTime - gameStartTime)
        scoreLabel.text = "\(score)s"

        applyMotion()

        if currentTime - lastHoleTime > holeInterval {
            spawnHole()
            lastHoleTime = currentTime
            holeInterval = max(1.4, holeInterval - 0.15)
        }
    }

    private func applyMotion() {
        #if targetEnvironment(simulator)
        ball.physicsBody?.applyForce(simulatorForce)
        #else
        if let motion = motionManager.deviceMotion {
            let gx = CGFloat(motion.gravity.x)
            let gy = CGFloat(motion.gravity.y)
            ball.physicsBody?.applyForce(CGVector(dx: gx * 68, dy: gy * 68))
        }
        #endif
    }

    // MARK: - Holes

    private func spawnHole() {
        let margin: CGFloat = 48
        let progress = min(1.0, CGFloat(score) / 60.0)
        let minR = 15 + progress * 10
        let maxR = 25 + progress * 16
        let finalRadius = CGFloat.random(in: minR...maxR)

        var position = randomBoardPosition(margin: margin)
        for _ in 0..<10 {
            let candidate = randomBoardPosition(margin: margin)
            if hypot(candidate.x - ball.position.x, candidate.y - ball.position.y) > finalRadius * 4 {
                position = candidate
                break
            }
        }

        let hole = SKShapeNode(circleOfRadius: finalRadius)
        hole.fillColor = .black
        hole.strokeColor = SKColor(red: 0.85, green: 0.1, blue: 0.1, alpha: 0.9)
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

    private func randomBoardPosition(margin: CGFloat) -> CGPoint {
        CGPoint(
            x: CGFloat.random(in: boardRect.minX + margin...boardRect.maxX - margin),
            y: CGFloat.random(in: boardRect.minY + margin...boardRect.maxY - margin)
        )
    }

    // MARK: - Physics Contact

    func didBegin(_ contact: SKPhysicsContact) {
        guard !isGameOver, !isInvincible else { return }
        let isHole = contact.bodyA.categoryBitMask == holeCategory
                  || contact.bodyB.categoryBitMask == holeCategory
        if isHole { ballFellInHole() }
    }

    // MARK: - Ball Events

    private func ballFellInHole() {
        lives -= 1
        updateLivesDisplay()

        if lives <= 0 {
            triggerGameOver()
            return
        }

        isInvincible = true
        ball.physicsBody?.velocity = .zero
        ball.physicsBody?.angularVelocity = 0
        ball.position = CGPoint(x: boardRect.midX, y: boardRect.midY)

        let flash = SKAction.repeat(.sequence([
            .run { [weak self] in self?.ball.alpha = 0.22 },
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

        let prevBest = highScore
        let isNewBest = score > prevBest
        if isNewBest { highScore = score }

        let overlay = SKShapeNode(rect: CGRect(
            x: -size.width / 2, y: -size.height / 2,
            width: size.width, height: size.height
        ))
        overlay.fillColor = SKColor(white: 0, alpha: 0.74)
        overlay.strokeColor = .clear
        overlay.zPosition = 20
        addChild(overlay)

        let gameOverLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        gameOverLabel.text = "GAME OVER"
        gameOverLabel.fontSize = 52
        gameOverLabel.fontColor = .white
        gameOverLabel.position = CGPoint(x: 0, y: 110)
        gameOverLabel.zPosition = 21
        addChild(gameOverLabel)

        let timeLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        timeLabel.text = "Survived  \(score)s"
        timeLabel.fontSize = 30
        timeLabel.fontColor = SKColor(red: 0.35, green: 0.78, blue: 1, alpha: 1)
        timeLabel.position = CGPoint(x: 0, y: 56)
        timeLabel.zPosition = 21
        addChild(timeLabel)

        if isNewBest {
            let newBestLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
            newBestLabel.text = "NEW BEST!"
            newBestLabel.fontSize = 24
            newBestLabel.fontColor = SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
            newBestLabel.position = CGPoint(x: 0, y: 16)
            newBestLabel.zPosition = 21
            addChild(newBestLabel)
        } else if prevBest > 0 {
            let bestLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
            bestLabel.text = "Best: \(prevBest)s"
            bestLabel.fontSize = 20
            bestLabel.fontColor = SKColor(white: 0.55, alpha: 1)
            bestLabel.position = CGPoint(x: 0, y: 16)
            bestLabel.zPosition = 21
            addChild(bestLabel)
        }

        let button = SKShapeNode(rectOf: CGSize(width: 224, height: 58), cornerRadius: 29)
        button.fillColor = SKColor(red: 0.22, green: 0.42, blue: 0.88, alpha: 1)
        button.strokeColor = .clear
        button.position = CGPoint(x: 0, y: -50)
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
        let loc = touch.location(in: self)
        if nodes(at: loc).contains(where: { $0.name == "restart" }) {
            let newScene = GameScene(size: size)
            newScene.scaleMode = scaleMode
            view?.presentScene(newScene, transition: .fade(withDuration: 0.4))
        }
    }

    #if targetEnvironment(simulator)
    private func updateSimulatorForce(_ touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let dx = (loc.x / (size.width / 2)) * 68
        let dy = (loc.y / (size.height / 2)) * 68
        simulatorForce = CGVector(dx: dx, dy: dy)
    }
    #endif

    // MARK: - Cleanup

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
