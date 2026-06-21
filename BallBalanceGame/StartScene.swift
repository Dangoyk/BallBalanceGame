import SpriteKit

class StartScene: SKScene {

    private var canTap = false

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.07, green: 0.09, blue: 0.15, alpha: 1)
        setupTitle()
        setupBall()
        setupDecorations()
        setupHighScore()
        setupTapLabel()
        setupInstructions()

        run(.sequence([
            .wait(forDuration: 0.4),
            .run { [weak self] in self?.canTap = true }
        ]))
    }

    // MARK: - Setup

    private func setupTitle() {
        let sub = SKLabelNode(fontNamed: "AvenirNext-Medium")
        sub.text = "BALL"
        sub.fontSize = 30
        sub.fontColor = SKColor(white: 0.65, alpha: 0.9)
        sub.position = CGPoint(x: 0, y: size.height * 0.24 + 36)
        sub.zPosition = 5
        addChild(sub)

        let main = SKLabelNode(fontNamed: "AvenirNext-Bold")
        main.text = "BALANCE"
        main.fontSize = 68
        main.fontColor = .white
        main.position = CGPoint(x: 0, y: size.height * 0.24)
        main.zPosition = 5
        addChild(main)

        let linePath = CGMutablePath()
        linePath.move(to: CGPoint(x: -70, y: 0))
        linePath.addLine(to: CGPoint(x: 70, y: 0))
        let line = SKShapeNode(path: linePath)
        line.strokeColor = SKColor(red: 0.22, green: 0.42, blue: 0.88, alpha: 0.75)
        line.lineWidth = 2
        line.position = CGPoint(x: 0, y: size.height * 0.24 - 46)
        line.zPosition = 5
        addChild(line)
    }

    private func setupBall() {
        let r: CGFloat = 44
        let ball = SKShapeNode(circleOfRadius: r)
        ball.fillColor = .white
        ball.strokeColor = SKColor(white: 0.88, alpha: 1)
        ball.lineWidth = 2
        ball.position = CGPoint(x: 0, y: size.height * 0.01)
        ball.zPosition = 5

        let shine = SKShapeNode(circleOfRadius: r * 0.28)
        shine.fillColor = SKColor(white: 1, alpha: 0.72)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -r * 0.28, y: r * 0.28)
        ball.addChild(shine)

        addChild(ball)

        ball.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 13, duration: 1.15),
            .moveBy(x: 0, y: -13, duration: 1.15)
        ])))
    }

    private func setupDecorations() {
        let holes: [(CGFloat, CGFloat, CGFloat)] = [
            (-size.width * 0.33, -size.height * 0.09, 28),
            ( size.width * 0.31,  size.height * 0.07, 20),
            (-size.width * 0.16, -size.height * 0.25, 16),
            ( size.width * 0.22, -size.height * 0.19, 24)
        ]
        for (x, y, r) in holes {
            let hole = SKShapeNode(circleOfRadius: r)
            hole.fillColor = SKColor(red: 0.04, green: 0.03, blue: 0.06, alpha: 1)
            hole.strokeColor = SKColor(red: 0.75, green: 0.10, blue: 0.10, alpha: 0.65)
            hole.lineWidth = 2
            hole.position = CGPoint(x: x, y: y)
            hole.zPosition = 3
            hole.alpha = 0.72
            addChild(hole)
        }

        let coins: [(CGFloat, CGFloat)] = [
            ( size.width * 0.36, -size.height * 0.08),
            (-size.width * 0.38,  size.height * 0.06)
        ]
        for (x, y) in coins {
            let coin = SKShapeNode(circleOfRadius: 14)
            coin.fillColor = SKColor(red: 1, green: 0.82, blue: 0.10, alpha: 1)
            coin.strokeColor = SKColor(red: 0.88, green: 0.62, blue: 0, alpha: 1)
            coin.lineWidth = 1.5
            coin.position = CGPoint(x: x, y: y)
            coin.zPosition = 3
            coin.alpha = 0.78
            addChild(coin)
            coin.run(.repeatForever(.sequence([
                .scale(to: 1.12, duration: 0.85),
                .scale(to: 0.90, duration: 0.85)
            ])))
        }
    }

    private func setupHighScore() {
        let best = UserDefaults.standard.integer(forKey: "BallBalanceHighScore")
        guard best > 0 else { return }
        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = "BEST  \(best)s"
        label.fontSize = 18
        label.fontColor = SKColor(red: 1, green: 0.82, blue: 0.10, alpha: 0.9)
        label.position = CGPoint(x: 0, y: -size.height * 0.16)
        label.zPosition = 5
        addChild(label)
    }

    private func setupTapLabel() {
        let tap = SKLabelNode(fontNamed: "AvenirNext-Bold")
        tap.text = "TAP TO PLAY"
        tap.fontSize = 22
        tap.fontColor = SKColor(red: 0.22, green: 0.42, blue: 0.88, alpha: 1)
        tap.position = CGPoint(x: 0, y: -size.height * 0.27)
        tap.zPosition = 5
        addChild(tap)
        tap.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.28, duration: 0.72),
            .fadeAlpha(to: 1.00, duration: 0.72)
        ])))
    }

    private func setupInstructions() {
        let lines = [
            "Tilt your phone to roll the ball",
            "Avoid holes  ·  Don't fall off the edge",
            "Collect gold coins  ·  Survive the wind"
        ]
        let startY = -size.height * 0.35
        for (i, text) in lines.enumerated() {
            let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
            label.text = text
            label.fontSize = 13
            label.fontColor = SKColor(white: 0.46, alpha: 0.9)
            label.position = CGPoint(x: 0, y: startY - CGFloat(i) * 22)
            label.zPosition = 5
            addChild(label)
        }
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard canTap else { return }
        canTap = false
        let game = GameScene(size: size)
        game.scaleMode = scaleMode
        game.anchorPoint = anchorPoint
        view?.presentScene(game, transition: .fade(withDuration: 0.5))
    }
}
