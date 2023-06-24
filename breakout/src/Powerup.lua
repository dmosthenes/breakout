--[[
    -- Power-up Class --

    Author: Matt Wise
    wise.matthewkyle@gmail.com

    Represents a power-up which, on collision with paddle, spawns
    two additionall balls to the screen.

]]

Powerup = Class{}

function Powerup:init()
    self.x = math.random(20, VIRTUAL_WIDTH - 20)
    self.y = - 10
    self.width = 16
    self.height = 16
    self.inPlay = false
    self.spawnTimer = math.random(10,25)
end

function Powerup:update(dt)
    -- if powerup is not in-play, increment spawntimer, else update position
    if not self.inPlay then
        self.spawnTimer = self.spawnTimer + 1
        if self.spawnTimer == 1000 then
            self.inPlay = true
        end
    elseif self.y > VIRTUAL_HEIGHT + 10 then
        self.inPlay = false
    else
        self.y = self.y + 1
    end
end

function Powerup:collides(target)
    -- check if left edge of either is further to the right than the right edge of the other
    if self.x > target.x + target.width / 2 or target.y > self.y + self.width / 2 then
        return false
    end

    -- check if top of each is below the bottom of the other
    if self.y > target.y + target.height / 2 or target.y > self.y + self.height / 2 then
        return false
    end

    -- if both conditions are false, objects are overlapping
    return true

end

function Powerup:render()
    if self.inPlay then
        love.graphics.draw(gTextures['main'], 
            -- multiply color by 4 (-1) to get our color offset, then add tier to that
            -- to draw the correct tier and color brick onto the screen
            GeneratePowerup(gTextures['main']),
            self.x, self.y)
    end
end