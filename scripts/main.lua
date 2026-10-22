-- Phase 1-8 entry, adapted from templates/scaffold-3d-character.lua.
-- The top-down orthographic whitebox replaces the template's shooter/FSM/follow camera.
local Phase1 = require("Factory/Phase1")
local RUN_STATIC_ART_QA = false -- Must be false in playable delivery.
local RUN_CHARACTER_QA = false -- Isolated presentation/route fixture; false in delivery.
local RUN_AUDIO_QA = false -- Independent save/preferences namespace; false in delivery.

function Start()
    if RUN_STATIC_ART_QA then require('Factory/LocalSave').Files={'burger-static-art-qa-a.json','burger-static-art-qa-b.json'} end
    if RUN_CHARACTER_QA then require('Factory/LocalSave').Files={'burger-character-qa-a.json','burger-character-qa-b.json'} end
    if RUN_AUDIO_QA then
        require('Factory/LocalSave').Files={'burger-audio-qa-a.json','burger-audio-qa-b.json'}
        require('Factory/UIPreferences').FileName='burger-audio-qa-ui.json'
    end
    Phase1.Start()
    if RUN_STATIC_ART_QA then require('Factory/StaticArtChecks').Run(Phase1.V06()) end
    if RUN_CHARACTER_QA then
        local review=require('Factory/CharacterNativeChecks').Run(Phase1.V06())
        -- Reuse the registered bridge; a second Update subscription would steal it.
        Phase1.PresentationReview=function(dt) review:Frame(dt) end
    end
    if RUN_AUDIO_QA then
        local c,r,h=Phase1.V06()
        local review=require('Factory/AudioNativeChecks').Run(c,r,h,Phase1)
        Phase1.PresentationReview=function(dt) review:Frame(dt) end
    end
end

function Stop()
    Phase1.Stop()
end
