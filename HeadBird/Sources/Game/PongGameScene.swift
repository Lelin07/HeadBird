import SpriteKit

final class PongGameScene: SKScene {
    private let state: GameState
    private let winningScore: Int

    private let playerPaddle = SKSpriteNode(color: NSColor.white.withAlphaComponent(0.75), size: CGSize(width: 8, height: 42))
    private let cpuPaddle = SKSpriteNode(color: NSColor.white.withAlphaComponent(0.55), size: CGSize(width: 8, height: 42))
    private let ball = SKShapeNode(circleOfRadius: 5)

    private var ballVelocity: CGPoint = .zero
    private var lastUpdateTime: TimeInterval = 0

    private let playerInsetX: CGFloat = 22
    private let cpuInsetX: CGFloat = 22
    private let maxPlayerPaddleSpeed: CGFloat = 240
    private let maxCPUPaddleSpeed: CGFloat = 205
    private let pitchVelocityGain: CGFloat = 220
    private let baseBallSpeed: CGFloat = 150
    private let maxBallSpeed: CGFloat = 340

    init(state: GameState, winningScore: Int = 7) {
        self.state = state
        self.winningScore = winningScore
        super.init(size: CGSize(width: 320, height: 180))
        scaleMode = .resizeFill
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0, y: 0)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func didMove(to view: SKView) {
        if playerPaddle.parent == nil {
            setupScene()
        }
    }

    func resetGame() {
        state.reset()
        lastUpdateTime = 0
        ballVelocity = .zero
        playerPaddle.position = CGPoint(x: playerInsetX, y: size.height * 0.5)
        cpuPaddle.position = CGPoint(x: size.width - cpuInsetX, y: size.height * 0.5)
        ball.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
    }

    func prepareForResume() {
        lastUpdateTime = 0
    }

    func startRound(towardRight: Bool) {
        ball.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        launchBall(towardRight: towardRight)
    }

    override func update(_ currentTime: TimeInterval) {
        guard state.isPlaying else { return }
        let delta = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 1.0 / 60.0
        lastUpdateTime = currentTime

        updatePaddles(deltaTime: delta)
        updateBall(deltaTime: delta)
        detectScoring()
    }

    private func setupScene() {
        let centerY = size.height * 0.5

        playerPaddle.position = CGPoint(x: playerInsetX, y: centerY)
        cpuPaddle.position = CGPoint(x: size.width - cpuInsetX, y: centerY)

        ball.fillColor = NSColor.white.withAlphaComponent(0.9)
        ball.strokeColor = .clear
        ball.position = CGPoint(x: size.width * 0.5, y: centerY)

        addChild(playerPaddle)
        addChild(cpuPaddle)
        addChild(ball)
    }

    private func updatePaddles(deltaTime: TimeInterval) {
        let desiredVelocity = CGFloat(state.pitchDelta) * pitchVelocityGain * CGFloat(state.sensitivity)
        let playerVelocity = clamp(desiredVelocity, min: -maxPlayerPaddleSpeed, max: maxPlayerPaddleSpeed)
        playerPaddle.position.y += playerVelocity * CGFloat(deltaTime)
        playerPaddle.position.y = clamp(
            playerPaddle.position.y,
            min: playerPaddle.size.height * 0.5,
            max: size.height - playerPaddle.size.height * 0.5
        )

        let deltaY = ball.position.y - cpuPaddle.position.y
        let cpuVelocity = clamp(deltaY * 3.2, min: -maxCPUPaddleSpeed, max: maxCPUPaddleSpeed)
        cpuPaddle.position.y += cpuVelocity * CGFloat(deltaTime)
        cpuPaddle.position.y = clamp(
            cpuPaddle.position.y,
            min: cpuPaddle.size.height * 0.5,
            max: size.height - cpuPaddle.size.height * 0.5
        )
    }

    private func updateBall(deltaTime: TimeInterval) {
        ball.position.x += ballVelocity.x * CGFloat(deltaTime)
        ball.position.y += ballVelocity.y * CGFloat(deltaTime)

        let radius = ball.frame.width * 0.5
        if ball.position.y <= radius {
            ball.position.y = radius
            ballVelocity.y = abs(ballVelocity.y)
        } else if ball.position.y >= size.height - radius {
            ball.position.y = size.height - radius
            ballVelocity.y = -abs(ballVelocity.y)
        }

        if ballVelocity.x < 0, ball.frame.intersects(playerPaddle.frame) {
            reflectBall(from: playerPaddle, towardRight: true)
        } else if ballVelocity.x > 0, ball.frame.intersects(cpuPaddle.frame) {
            reflectBall(from: cpuPaddle, towardRight: false)
        }
    }

    private func detectScoring() {
        let radius = ball.frame.width * 0.5
        if ball.position.x < -radius {
            state.incrementOpponentScore()
            if state.opponentScore >= winningScore {
                state.endGame(message: "CPU wins \(state.opponentScore)-\(state.score)")
                ballVelocity = .zero
                return
            }
            startRound(towardRight: false)
            return
        }

        if ball.position.x > size.width + radius {
            state.incrementScore()
            if state.score >= winningScore {
                state.endGame(message: "You win \(state.score)-\(state.opponentScore)")
                ballVelocity = .zero
                return
            }
            startRound(towardRight: true)
        }
    }

    private func launchBall(towardRight: Bool) {
        let direction: CGFloat = towardRight ? 1 : -1
        let vertical = CGFloat.random(in: -0.35...0.35) * baseBallSpeed
        ballVelocity = CGPoint(x: direction * baseBallSpeed, y: vertical)
    }

    private func reflectBall(from paddle: SKSpriteNode, towardRight: Bool) {
        let offset = (ball.position.y - paddle.position.y) / (paddle.size.height * 0.5)
        let normalizedOffset = clamp(offset, min: -1, max: 1)
        let currentSpeed = max(baseBallSpeed, hypot(ballVelocity.x, ballVelocity.y))
        let speed = min(maxBallSpeed, currentSpeed * 1.04 + 8)
        let horizontal = max(baseBallSpeed * 0.65, speed * 0.75)
        let vertical = normalizedOffset * speed * 0.55

        ballVelocity = CGPoint(
            x: towardRight ? abs(horizontal) : -abs(horizontal),
            y: vertical
        )

        let radius = ball.frame.width * 0.5
        if towardRight {
            ball.position.x = paddle.frame.maxX + radius + 0.5
        } else {
            ball.position.x = paddle.frame.minX - radius - 0.5
        }
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }
}
