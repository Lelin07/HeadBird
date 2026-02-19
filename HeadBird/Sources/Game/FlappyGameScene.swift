import SpriteKit

final class FlappyGameScene: SKScene {
    private let state: GameState
    private let bird = SKShapeNode(circleOfRadius: 10)
    private var lastUpdateTime: TimeInterval = 0
    private var lastSpawnTime: TimeInterval = 0
    private var resetSpawnTimerOnNextFrame: Bool = false
    private var birdVelocity: CGFloat = 0
    private var obstacles: [ObstacleNode] = []

    private let obstacleSpeed: CGFloat = 120
    private let obstacleWidth: CGFloat = 36
    private let gapHeight: CGFloat = 90
    private let spawnInterval: TimeInterval = 1.6
    private let maxPitchVelocity: CGFloat = 240
    private let velocityGain: CGFloat = 220

    init(state: GameState) {
        self.state = state
        super.init(size: CGSize(width: 320, height: 180))
        scaleMode = .resizeFill
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0, y: 0)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func didMove(to view: SKView) {
        setupScene()
    }

    func resetGame() {
        removeAllActions()
        obstacles.forEach { $0.removeFromParent() }
        obstacles.removeAll()
        lastUpdateTime = 0
        lastSpawnTime = 0
        resetSpawnTimerOnNextFrame = false
        birdVelocity = 0
        bird.position = CGPoint(x: size.width * 0.25, y: size.height * 0.5)
    }

    func prepareForResume() {
        lastUpdateTime = 0
        resetSpawnTimerOnNextFrame = true
    }

    override func update(_ currentTime: TimeInterval) {
        guard state.isPlaying else { return }

        if resetSpawnTimerOnNextFrame {
            lastSpawnTime = currentTime
            resetSpawnTimerOnNextFrame = false
        }

        let delta = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 1.0 / 60.0
        lastUpdateTime = currentTime

        updateBird(deltaTime: delta)
        updateObstacles(deltaTime: delta, currentTime: currentTime)
        checkCollisions()
    }

    private func setupScene() {
        bird.fillColor = NSColor.white.withAlphaComponent(0.85)
        bird.strokeColor = .clear
        bird.position = CGPoint(x: size.width * 0.25, y: size.height * 0.5)
        addChild(bird)
    }

    private func updateBird(deltaTime: TimeInterval) {
        let targetVelocity = CGFloat(state.pitchDelta) * velocityGain * CGFloat(state.sensitivity)
        let clampedVelocity = clamp(targetVelocity, min: -maxPitchVelocity, max: maxPitchVelocity)
        birdVelocity = birdVelocity * 0.85 + clampedVelocity * 0.15
        bird.position.y += birdVelocity * CGFloat(deltaTime)

        if bird.position.y < 10 || bird.position.y > size.height - 10 {
            state.endGame()
        }
    }

    private func updateObstacles(deltaTime: TimeInterval, currentTime: TimeInterval) {
        if currentTime - lastSpawnTime > spawnInterval {
            spawnObstacle()
            lastSpawnTime = currentTime
        }

        for obstacle in obstacles {
            obstacle.position.x -= obstacleSpeed * CGFloat(deltaTime)
            if !obstacle.scored && obstacle.position.x + obstacle.width / 2 < bird.position.x {
                obstacle.scored = true
                state.incrementScore()
            }
        }

        obstacles.removeAll { obstacle in
            if obstacle.position.x + obstacle.width < 0 {
                obstacle.removeFromParent()
                return true
            }
            return false
        }
    }

    private func spawnObstacle() {
        let margin: CGFloat = 20
        let minCenter = gapHeight / 2 + margin
        let maxCenter = size.height - gapHeight / 2 - margin
        let gapCenter = CGFloat.random(in: minCenter...maxCenter)

        let obstacle = ObstacleNode(
            sceneHeight: size.height,
            width: obstacleWidth,
            gapHeight: gapHeight,
            gapCenter: gapCenter
        )
        obstacle.position = CGPoint(x: size.width + obstacleWidth, y: 0)
        addChild(obstacle)
        obstacles.append(obstacle)
    }

    private func checkCollisions() {
        let birdFrame = bird.calculateAccumulatedFrame()
        for obstacle in obstacles {
            if obstacle.collides(with: birdFrame) {
                state.endGame()
                break
            }
        }
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }
}

private final class ObstacleNode: SKNode {
    let width: CGFloat
    private let topNode: SKSpriteNode
    private let bottomNode: SKSpriteNode
    var scored: Bool = false

    init(sceneHeight: CGFloat, width: CGFloat, gapHeight: CGFloat, gapCenter: CGFloat) {
        self.width = width
        let obstacleColor = NSColor.white.withAlphaComponent(0.25)

        let bottomHeight = max(gapCenter - gapHeight / 2, 0)
        let topHeight = max(sceneHeight - (gapCenter + gapHeight / 2), 0)

        bottomNode = SKSpriteNode(color: obstacleColor, size: CGSize(width: width, height: bottomHeight))
        topNode = SKSpriteNode(color: obstacleColor, size: CGSize(width: width, height: topHeight))

        bottomNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        topNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        bottomNode.position = CGPoint(x: 0, y: bottomHeight / 2)
        topNode.position = CGPoint(x: 0, y: gapCenter + gapHeight / 2 + topHeight / 2)

        super.init()

        addChild(bottomNode)
        addChild(topNode)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func collides(with birdFrame: CGRect) -> Bool {
        guard let scene else { return false }
        let bottomLocal = bottomNode.frame
        let topLocal = topNode.frame
        let bottomFrame = convertRect(bottomLocal, to: scene)
        let topFrame = convertRect(topLocal, to: scene)
        return birdFrame.intersects(bottomFrame) || birdFrame.intersects(topFrame)
    }

    private func convertRect(_ rect: CGRect, to scene: SKScene) -> CGRect {
        let minPoint = convert(CGPoint(x: rect.minX, y: rect.minY), to: scene)
        let maxPoint = convert(CGPoint(x: rect.maxX, y: rect.maxY), to: scene)
        let origin = CGPoint(x: min(minPoint.x, maxPoint.x), y: min(minPoint.y, maxPoint.y))
        let size = CGSize(width: abs(maxPoint.x - minPoint.x), height: abs(maxPoint.y - minPoint.y))
        return CGRect(origin: origin, size: size)
    }
}
