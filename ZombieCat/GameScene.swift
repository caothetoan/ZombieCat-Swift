/*
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import SpriteKit

struct PhysicsType  {
  static let none            :UInt32  =   0
  static let player          :UInt32  =   1
  static let wall            :UInt32  =   2
  static let beaker          :UInt32  =   4
  static let explosionRadius :UInt32  =   8
  static let cat             :UInt32  =   16
  static let zombieCat       :UInt32  =   32
}

class GameScene: SKScene {
  var pinBeakerToZombieArm: SKPhysicsJointFixed?
  var beakerReady = false
  
  var explosionTextures = [SKTexture]()
  
  let sleepyTexture = SKTexture(imageNamed: "cat_sleepy")
  let awakeTexture = SKTexture(imageNamed: "cat_awake")
  
  var previousThrowPower = 100.0
  var previousThrowAngle = 0.0
  var currentPower = 100.0
  var currentAngle = 0.0
  var powerMeterNode: SKSpriteNode? = nil
  var powerMeterFilledNode: SKSpriteNode? = nil
  
  var beakersLeft = 3
  var catsRemaining = 2
  
  override func didMove(to view: SKView) {
    newProjectile()
    
    for i in 0...8 {
      explosionTextures.append(SKTexture(imageNamed: "regularExplosion0\(i)"))
    }
    
    physicsWorld.contactDelegate = self
    
    powerMeterNode = childNode(withName: "powerMeter") as? SKSpriteNode
    powerMeterFilledNode = powerMeterNode?.childNode(withName: "powerMeterFilled") as? SKSpriteNode
    
    let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
    view.addGestureRecognizer(panRecognizer)
  }
  
  func newProjectile () {
    let beaker = SKSpriteNode(imageNamed: "beaker")
    beaker.name = "beaker"
    beaker.zPosition = 5
    beaker.position = CGPoint(x: 120, y: 625)
    let beakerBody = SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 40))
    beakerBody.mass = 1.0
    beakerBody.categoryBitMask = PhysicsType.beaker
    beakerBody.collisionBitMask = PhysicsType.wall | PhysicsType.cat | PhysicsType.zombieCat
    beaker.physicsBody = beakerBody
    addChild(beaker)
    
    if let armBody = childNode(withName: "player")?.childNode(withName: "arm")?.physicsBody {
      pinBeakerToZombieArm = SKPhysicsJointFixed.joint(withBodyA: armBody, bodyB: beakerBody, anchor: CGPoint.zero)
      physicsWorld.add(pinBeakerToZombieArm!)
      beakerReady = true
    }
    
    let cloud = SKSpriteNode(imageNamed: "regularExplosion00")
    cloud.name = "cloud"
    cloud.setScale(0)
    cloud.zPosition = 1
    beaker.addChild(cloud)
    
    let explosionRadius = SKSpriteNode(color: UIColor.clear, size: CGSize(width: 200, height: 200))
    explosionRadius.name = "explosionRadius"
    
    let explosionRadiusBody = SKPhysicsBody(circleOfRadius: 200)
    explosionRadiusBody.mass = 0.01
    explosionRadiusBody.pinned = true
    explosionRadiusBody.categoryBitMask = PhysicsType.explosionRadius
    explosionRadiusBody.collisionBitMask = PhysicsType.none
    explosionRadiusBody.contactTestBitMask = PhysicsType.cat
    
    explosionRadius.physicsBody = explosionRadiusBody
    beaker.addChild(explosionRadius)
  }
  
  func tossBeaker(strength: CGVector) {
    if beakerReady == true {
      if let beaker = childNode(withName: "beaker") {
        if let arm = childNode(withName: "player")?.childNode(withName: "arm") {
          let toss = SKAction.run() {
            self.physicsWorld.remove(self.pinBeakerToZombieArm!)
            beaker.physicsBody?.applyImpulse(strength)
            beaker.physicsBody?.applyAngularImpulse(0.1125)
            self.beakerReady = false
          }
          let followTrough = SKAction.rotate(byAngle: -6*3.14, duration: 2.0)
          
          arm.run(SKAction.sequence([toss, followTrough]))
        }
        
        // explosion added later
        if let cloud = beaker.childNode(withName: "cloud"),
          let explosionRadius = beaker.childNode(withName: "explosionRadius") {
          
          // 1
          let fuse = SKAction.wait(forDuration: 4.0)
          let expandCloud = SKAction.scale(to: 3.5, duration: 0.25)
          let contractCloud = SKAction.scale(to: 0, duration: 0.25)
          
          previousThrowPower = currentPower
          previousThrowAngle = currentAngle
          
          if let sparkNode = SKEmitterNode(fileNamed: "BeakerSparkTrail") {
            beaker.addChild(sparkNode)
          }
          
          if let smokeNode = SKEmitterNode(fileNamed: "BeakerSmoke") {
            smokeNode.targetNode = self
            beaker.addChild(smokeNode)
          }
          
          // 2
          let removeBeaker = SKAction.run() {
            beaker.removeFromParent()
          }
          let animate = SKAction.animate(with: explosionTextures, timePerFrame: 0.056)
          
          let greenColor = SKColor(red: 57.0/255.0, green: 250.0/255.0, blue: 146.0/255.0, alpha: 1.0)
          let turnGreen = SKAction.colorize(with: greenColor, colorBlendFactor: 0.7, duration: 0.3)
          
          let zombifyContactedCat = SKAction.run() {
            if let physicsBody = explosionRadius.physicsBody {
              for contactedBody in physicsBody.allContactedBodies() {
                if (physicsBody.contactTestBitMask & contactedBody.categoryBitMask) != 0  ||
                  (contactedBody.contactTestBitMask & physicsBody.categoryBitMask) != 0  {
                  if let catNode = contactedBody.node as? SKSpriteNode {
                    catNode.texture = self.sleepyTexture
                  }
                  contactedBody.node?.run(turnGreen)
                  self.catsRemaining -= 1
                  contactedBody.categoryBitMask = PhysicsType.zombieCat
                }
              }
            }
          }
          
          let expandContractCloud = SKAction.sequence([expandCloud, zombifyContactedCat, contractCloud])
          let animateCloud = SKAction.group([animate, expandContractCloud])
          
          let boom = SKAction.sequence([fuse, animateCloud, removeBeaker])
          
          // 3
          let respawnBeakerDelay = SKAction.wait(forDuration: 1.0)
          let respawnBeaker = SKAction.run() {
            self.newProjectile()
          }
          let reload = SKAction.sequence([respawnBeakerDelay, respawnBeaker])
          
          // 4
          cloud.run(boom) {
            self.beakersLeft -= 1
            self.run(reload)
            self.updateLabels()
            self.checkEndGame()
          }
        }
      }
    }
  }
  
  //  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
  //    tossBeaker(strength: CGVector(dx: 1400, dy: 1150))
  //  }
  
  @objc func handlePan(recognizer:UIPanGestureRecognizer) {
    if recognizer.state == UIGestureRecognizerState.began {
      // do any initialization here
    }
    
    if recognizer.state == UIGestureRecognizerState.changed {
      // the position of the drag has moved
      let translation = recognizer.translation(in: self.view)
      updatePowerMeter(translation: translation)
    }
    
    if recognizer.state == UIGestureRecognizerState.ended {
      // finish up
      let maxPowerImpulse = 2500.0
      let currentImpulse = maxPowerImpulse * currentPower/100.0
      
      let strength = CGVector( dx: currentImpulse * cos(currentAngle),
                               dy: currentImpulse * sin(currentAngle) )
      tossBeaker(strength: strength)
    }
  }
  
  func updatePowerMeter(translation: CGPoint) {
    let powerTranslation = translation.x
    let powerScale = 2.0
    
    var power = Float(previousThrowPower) + Float(powerTranslation) / Float(powerScale)
    power = min(power, 100)
    power = max(power, 0)
    
    currentPower = Double(power)
    powerMeterFilledNode?.xScale = CGFloat(power/100.0)
    
    let angleTranslation = translation.y
    let angleScale = 150.0
    
    var angle = Float(previousThrowAngle) - Float(angleTranslation) / Float(angleScale)
    angle = min(angle, Float(M_PI_2))
    angle = max(angle, 0)
    
    currentAngle = Double(angle)
    powerMeterNode?.zRotation = CGFloat(angle)
  }
  
  func updateLabels() {
    if let beakerLabel = childNode(withName: "beakersLeftLabel") as? SKLabelNode {
      beakerLabel.text = "\(beakersLeft)"
    }
    
    if let catsLabel = childNode(withName: "catsRemainingLabel") as? SKLabelNode {
      catsLabel.text = "\(catsRemaining)"
    }
  }
  
  func checkEndGame() {
    if catsRemaining == 0 {
      print("you win")
      if let gameOverScene = GameOverScene(fileNamed: "GameOverScene") {
        gameOverScene.scaleMode = scaleMode
        gameOverScene.won = true
        view?.presentScene(gameOverScene)
      }
      return
    }
    
    if beakersLeft == 0 {
      print("you lose")
      if let gameOverScene = GameOverScene(fileNamed: "GameOverScene") {
        gameOverScene.scaleMode = scaleMode
        view?.presentScene(gameOverScene)
      }
    }
  }
  
}

// MARK: - SKPhysicsContactDelegate
extension GameScene: SKPhysicsContactDelegate {
  
  func didBegin(_ contact: SKPhysicsContact) {
    if (contact.bodyA.categoryBitMask == PhysicsType.cat) {
      if let catNode = contact.bodyA.node as? SKSpriteNode {
        catNode.texture = awakeTexture
      }
    }
    
    if (contact.bodyB.categoryBitMask == PhysicsType.cat) {
      if let catNode = contact.bodyB.node as? SKSpriteNode {
        catNode.texture = awakeTexture
      }
    }
  }
  
  func didEnd(_ contact: SKPhysicsContact) {
    if (contact.bodyA.categoryBitMask == PhysicsType.cat) {
      if let catNode = contact.bodyA.node as? SKSpriteNode {
        catNode.texture = sleepyTexture
      }
    }
    
    if (contact.bodyB.categoryBitMask == PhysicsType.cat) {
      if let catNode = contact.bodyB.node as? SKSpriteNode {
        catNode.texture = sleepyTexture
      }
    }
  }
}
