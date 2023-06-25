--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.ball = params.ball
    self.level = params.level

    self.recoverPoints = 5000

    -- give ball random starting velocity
    self.ball.dx = math.random(-200, 200)
    self.ball.dy = math.random(-50, -60)

    -- store powerup from serve state
    self.powerup = params.powerup

    -- space for extra balls
    self.extraOne = params.extraOne
    self.extraTwo = params.extraTwo

    -- increment size according to separate score counter
    self.growScore = 0

    -- debug flag
    -- self.printOne = false
end


-- util function for checking collision between given ball and paddle
function updatePaddleCollision(ball, paddle)

    if ball:collides(paddle) then
        -- raise ball above paddle in case it goes below it, then reverse dy
        ball.y = paddle.y - 8
        ball.dy = -ball.dy

        --
        -- tweak angle of bounce based on where it hits the paddle
        --

        -- if we hit the paddle on its left side while moving left...
        if ball.x < paddle.x + (paddle.width / 2) and paddle.dx < 0 then
            ball.dx = -50 + -(8 * (paddle.x + paddle.width / 2 - ball.x))
        
        -- else if we hit the paddle on its right side while moving right...
        elseif ball.x > paddle.x + (paddle.width / 2) and paddle.dx > 0 then
            ball.dx = 50 + (8 * math.abs(paddle.x + paddle.width / 2 - ball.x))
        end

        gSounds['paddle-hit']:play()
    end

end

function updateBrickCollision(self, ball)
    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do

        -- only check collision if we're in play
        if brick.inPlay and ball:collides(brick) then

            -- add to score
            self.score = self.score + (brick.tier * 200 + brick.color * 25)

            -- copy to grow score
            self.growScore = self.growScore + (brick.tier * 200 + brick.color * 25)

            -- trigger the brick's hit function, which removes it from play
            brick:hit()

            -- if we have enough points, recover a point of health
            if self.score > self.recoverPoints then
                -- can't go above 3 health
                self.health = math.min(3, self.health + 1)

                -- multiply recover points by 2
                self.recoverPoints = self.recoverPoints + math.min(100000, self.recoverPoints * 2)

                -- play recover sound effect
                gSounds['recover']:play()
            end

            -- go to our victory screen if there are no more bricks left
            if self:checkVictory() then
                gSounds['victory']:play()

                gStateMachine:change('victory', {
                    level = self.level,
                    paddle = self.paddle,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    ball = self.ball,
                    recoverPoints = self.recoverPoints
                })
            end

            --
            -- collision code for bricks
            --
            -- we check to see if the opposite side of our velocity is outside of the brick;
            -- if it is, we trigger a collision on that side. else we're within the X + width of
            -- the brick and should check to see if the top or bottom edge is outside of the brick,
            -- colliding on the top or bottom accordingly 
            --

            -- left edge; only check if we're moving right, and offset the check by a couple of pixels
            -- so that flush corner hits register as Y flips, not X flips
            if ball.x + 2 < brick.x and ball.dx > 0 then
                
                -- flip x velocity and reset position outside of brick
                ball.dx = -ball.dx
                ball.x = brick.x - 8
            
            -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
            -- so that flush corner hits register as Y flips, not X flips
            elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                
                -- flip x velocity and reset position outside of brick
                ball.dx = -ball.dx
                ball.x = brick.x + 32
            
            -- top edge if no X collisions, always check
            elseif ball.y < brick.y then
                
                -- flip y velocity and reset position outside of brick
                ball.dy = -ball.dy
                ball.y = brick.y - 8
            
            -- bottom edge if no X collisions or top collision, last possibility
            else
                
                -- flip y velocity and reset position outside of brick
                ball.dy = -ball.dy
                ball.y = brick.y + 16
            end

            -- slightly scale the y velocity to speed up the game, capping at +- 150
            if math.abs(ball.dy) < 150 then
                ball.dy = ball.dy * 1.02
            end

            -- only allow colliding with one brick, for corners
            break
        end
    end

    -- grow paddle if growScore is sufficiently high
    if self.growScore >= 500 then
        self.paddle:grow()
        self.growScore = 0
    end

end

function gameOver(self)
    self.health = self.health - 1
    gSounds['hurt']:play()

    if self.health == 0 then
        gStateMachine:change('game-over', {
            score = self.score,
            highScores = self.highScores
        })
    else
        -- self.printOne = false
        -- shrink paddle
        self.paddle:shrink()
        gStateMachine:change('serve', {
            -- paddle = self.paddle:shrink(),
            paddle = self.paddle,
            bricks = self.bricks,
            health = self.health,
            score = self.score,
            highScores = self.highScores,
            level = self.level,
            recoverPoints = self.recoverPoints,

            -- pass powerup back to serve state to keep continuous
            powerup = self.powerup,
            extraOne = nil,
            extraTwo = nil

        })
    end

    self.extraOne = nil
    self.extraTwo = nil

end

function initNewBall(ball)
    ball = Ball()
    ball:reset()
    ball.skin = math.random(7)
    ball.dx = math.random(-200, 200)
    ball.dy = math.random(-50, -60)
    return ball

end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)
    self.ball:update(dt)
    self.powerup:update(dt)

    -- update positions of extra balls once spawned
    if self.extraOne ~= nil then
        self.extraOne:update(dt)
        self.extraTwo:update(dt)

    end

    updatePaddleCollision(self.ball, self.paddle)

    -- if extra balls are spawned, also check their collisions
    if self.extraOne ~= nil then
        updatePaddleCollision(self.extraOne, self.paddle)
        updatePaddleCollision(self.extraTwo, self.paddle)
    end

    if self.extraOne == nil and self.powerup:collides(self.paddle) then
        -- reset powerup
        self.powerup.inPlay = false

        -- generate two additional balls
        self.extraOne = initNewBall(self.extraOne)
        self.extraTwo = initNewBall(self.extraTwo)


        -- cheap way to fix a bug whereby additional balls would spawn at the start of each new
        -- serve state because powerup was detected again to be colliding with the Paddle
        -- fix this properly later
        self.powerup.y = VIRTUAL_HEIGHT - 10

    end

    updateBrickCollision(self, self.ball)

    if self.extraOne ~= nil then
        updateBrickCollision(self, self.extraOne)
        updateBrickCollision(self, self.extraTwo)
    end

    -- if ball (or all balls) goes below bounds, revert to serve state and decrease health
    if self.extraOne ~= nil then
        if self.ball.y >= VIRTUAL_HEIGHT and self.extraOne.y >= VIRTUAL_HEIGHT and self.extraTwo.y >= VIRTUAL_HEIGHT then
            self.extraOne = nil
            self.extraTwo = nil
            gameOver(self)
        end
    else
        if self.ball.y >= VIRTUAL_HEIGHT then
            gameOver(self)
        end
    end
    
    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    self.ball:render()

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end

    -- render power-up
    self.powerup:render()

    -- render extra balls once spawned
    if self.extraOne ~= nil then


        -- debug extra balls
        -- if not self.printOne then
        --     print("ball: ", self.ball, " extra 1: ", self.extraOne, " extra 2: ", self.extraTwo)
        --     self.printOne = true
        -- end
    

        self.extraOne:render()
        self.extraTwo:render()
    end

end



function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end