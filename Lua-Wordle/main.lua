love.window.setMode(1200, 800, {vsync=0})
love.window.setTitle("wortraum")

local m = require("wordle_core")

local state = "LOADING"
local best_word = ""
local best_score = 0
local active_count = 0

-- UI State
local feedback_input = ""
local message = "Loading Native Core..."

local last_calculation_time = 0

function love.load()
    love.graphics.setNewFont(16)
    
    -- Using the FFI native C Core implementation (Instantaneous)
    active_count = m.LoadWords("allowed_words.txt", "possible_words.txt")
    
    if active_count > 0 then
        state = "CALCULATING"
    else
        state = "ERROR"
        message = "Failed to load Wordle Dictionary texts."
    end
end

function love.update(dt)
    if state == "CALCULATING" then
        local start = love.timer.getTime()
        
        -- Score every guess in the native C core
        local b_idx, b_score = m.CalculateBestMove()
        best_word = string.upper(m.GetWord(b_idx))
        best_score = b_score
        
        last_calculation_time = love.timer.getTime() - start
        
        state = "WAITING_INPUT"
        message = string.format("Native Best: %s (Score: %d) | Native Time: %.1fms", best_word, b_score, last_calculation_time * 1000)
    end
end

function love.keypressed(key)
    if state == "WAITING_INPUT" then
        if key == "backspace" then
            feedback_input = feedback_input:sub(1, -2)
        elseif key == "return" and #feedback_input == 5 then
            local pattern = m.FeedbackToPattern(feedback_input)
            
            local g_idx = 0
            for i = 0, m.allowed_count - 1 do
                if string.upper(m.GetWord(i)) == best_word then
                    g_idx = i
                    break
                end
            end
            
            -- Filter
            active_count = m.FilterPossible(g_idx, pattern)
            
            if active_count == 1 then
                state = "SOLVED"
                for i = 0, m.allowed_count - 1 do
                    if m.IsPossible(i) then
                        best_word = string.upper(m.GetWord(i))
                        break
                    end
                end
                message = "SOLVED! The word is: " .. best_word
            elseif active_count == 0 then
                state = "ERROR"
                message = "No words remaining. Check your feedback."
            else
                feedback_input = ""
                state = "CALCULATING"
                message = "Recalculating (native)..."
            end
        else
            if (key == "0" or key == "1" or key == "2") and #feedback_input < 5 then
                feedback_input = feedback_input .. key
            end
        end
    end
end

function love.draw()
    love.graphics.clear(0.08, 0.08, 0.1)
    
    -- Telemetry
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("wortraum (native C core via LuaJIT FFI)", 20, 20)
    love.graphics.print(string.format("Possible Words Remaining: %d", active_count), 20, 50)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 20, 80)
    
    -- Main Status
    if state == "CALCULATING" then
        love.graphics.setColor(1, 0.8, 0.2)
    elseif state == "SOLVED" then
        love.graphics.setColor(0.2, 1, 0.2)
    else
        love.graphics.setColor(0.2, 0.8, 1)
    end
    
    love.graphics.printf(message, 0, 150, 1200, "center")
    
    if state == "WAITING_INPUT" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Enter Feedback (0=Gray, 1=Yellow, 2=Green): " .. feedback_input .. "_", 0, 200, 1200, "center")
    end
    
    -- Word Cloud Rendering 
    love.graphics.setColor(1, 1, 1, 0.3)
    local x, y = 20, 270
    local drawn = 0
    for i = 0, m.allowed_count - 1 do
        if m.IsPossible(i) then
            local is_candidate = m.IsAnswer(i)
            local w = string.upper(m.GetWord(i))
            
            if w == best_word then
                love.graphics.setColor(1, 0.8, 0.2, 1)
                love.graphics.print(w .. (is_candidate and "*" or ""), x, y)
                love.graphics.setColor(1, 1, 1, 0.3)
            else
                if is_candidate then
                    love.graphics.setColor(0.5, 0.8, 1, 0.5) -- Slight color for candidates
                    love.graphics.print(w, x, y)
                else
                    love.graphics.setColor(1, 1, 1, 0.3)
                    love.graphics.print(w, x, y)
                end
            end
            
            x = x + 75
            if x > 1130 then
                x = 20
                y = y + 25
            end
            
            drawn = drawn + 1
            if drawn > 300 then 
                love.graphics.print("... (+" .. (active_count - 300) .. " more)", x, y)
                break 
            end
        end
    end
    
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.print("* = Official Solution Candidate", 20, 770)
end
