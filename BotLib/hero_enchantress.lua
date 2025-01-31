local X             = {}
local bot           = GetBot()

local J             = require( GetScriptDirectory()..'/FunLib/jmz_func' )
local Minion        = dofile( GetScriptDirectory()..'/FunLib/aba_minion' )
local sTalentList   = J.Skill.GetTalentList( bot )
local sAbilityList  = J.Skill.GetAbilityList( bot )
local sOutfitType   = J.Item.GetOutfitType( bot )

local tTalentTreeList = {--pos4,5
                        ['t25'] = {0, 10},
                        ['t20'] = {0, 10},
                        ['t15'] = {0, 10},
                        ['t10'] = {10, 0},
}

local tAllAbilityBuildList = {
						{2,3,2,3,2,6,2,1,1,1,1,6,3,3,6},--pos4,5
}

local nAbilityBuildList = J.Skill.GetRandomBuild(tAllAbilityBuildList)

local nTalentBuildList = J.Skill.GetTalentBuild(tTalentTreeList)

local tOutFitList = {}

tOutFitList['outfit_carry'] = tOutFitList['outfit_carry']

tOutFitList['outfit_mid'] = tOutFitList['outfit_carry']

tOutFitList['outfit_tank'] = tOutFitList['outfit_carry']

tOutFitList['outfit_priest'] = {
    "item_double_tango",
    "item_double_branches",
    "item_faerie_fire",
    "item_blood_grenade",

    "item_magic_wand",
    "item_boots",
    "item_hurricane_pike",--
    "item_aghanims_shard",
    "item_mage_slayer",--
    "item_boots_of_bearing",--
    "item_moon_shard",--
    "item_bloodthorn",--
    "item_sheepstick",--
    "item_ultimate_scepter_2",
}

tOutFitList['outfit_mage'] = {
    "item_double_tango",
    "item_double_branches",
    "item_faerie_fire",
    "item_blood_grenade",

    "item_magic_wand",
    "item_boots",
    "item_hurricane_pike",--
    "item_aghanims_shard",
    "item_mage_slayer",--
    "item_guardian_greaves",--
    "item_moon_shard",--
    "item_bloodthorn",--
    "item_sheepstick",--
    "item_ultimate_scepter_2",
}

X['sBuyList'] = tOutFitList[sOutfitType]

Pos4SellList = {
	"item_magic_wand",
}

Pos5SellList = {
    "item_magic_wand",
}

X['sSellList'] = {}

if sOutfitType == "outfit_priest"
then
    X['sSellList'] = Pos4SellList
elseif sOutfitType == "outfit_mage"
then
    X['sSellList'] = Pos5SellList
end

if J.Role.IsPvNMode() or J.Role.IsAllShadow() then X['sBuyList'], X['sSellList'] = { 'PvN_antimage' }, {} end

nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] = J.SetUserHeroInit( nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] )

X['sSkillList'] = J.Skill.GetSkillList( sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList )

X['bDeafaultAbility'] = false
X['bDeafaultItem'] = false

function X.MinionThink(hMinionUnit)
    Minion.MinionThink(hMinionUnit)
end

local Impetus           = bot:GetAbilityByName('enchantress_impetus')
local Enchant           = bot:GetAbilityByName('enchantress_enchant')
local NaturesAttendant  = bot:GetAbilityByName('enchantress_natures_attendants')
local Sproink           = bot:GetAbilityByName('enchantress_bunny_hop')
local LittleFriends     = bot:GetAbilityByName('enchantress_little_friends')
-- local Untouchable       = bot:GetAbilityByName('enchantress_untouchable')

local ImpetusDesire
local EnchantDesire, EnchantTarget
local NaturesAttendantDesire
local SproinkDesire
local LittleFriendsDesire, LittleFriendsTarget

function X.SkillsComplement()
	if J.CanNotUseAbility(bot)
    then
        return
    end

    LittleFriendsDesire, LittleFriendsTarget = X.ConsiderLittleFriends()
    if LittleFriendsDesire > 0
    then
        bot:Action_UseAbilityOnEntity(LittleFriends, LittleFriendsTarget)
        return
    end

    ImpetusDesire = X.ConsiderImpetus()
    if ImpetusDesire > 0
    then
        return
    end

    SproinkDesire = X.ConsiderSproink()
    if SproinkDesire > 0
    then
        bot:Action_UseAbility(Sproink)
        return
    end

    NaturesAttendantDesire = X.ConsiderNaturesAttendant()
    if NaturesAttendantDesire > 0
    then
        bot:Action_UseAbility(NaturesAttendant)
        return
    end

    EnchantDesire, EnchantTarget = X.ConsiderEnchant()
    if EnchantDesire > 0
    then
        bot:Action_UseAbilityOnEntity(Enchant, EnchantTarget)
        return
    end
end

function X.ConsiderImpetus()
    if not Impetus:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE
    end

    local nAttackRange = bot:GetAttackRange()
    local nAbilityLevel = Impetus:GetLevel()
    local botTarget = J.GetProperTarget(bot)

    if J.IsGoingOnSomeone(bot)
    then
        local nInRangeAlly = bot:GetNearbyHeroes(nAttackRange + 100, false, BOT_MODE_NONE)
        local nInRangeEnemy = bot:GetNearbyHeroes(nAttackRange, true, BOT_MODE_NONE)

        if  J.IsValidTarget(botTarget)
        and J.IsInRange(bot, botTarget, nAttackRange)
        and J.CanCastOnNonMagicImmune(botTarget)
        and not J.IsSuspiciousIllusion(botTarget)
        and not botTarget:HasModifier('modifier_abaddon_borrowed_time')
        and nInRangeAlly ~= nil and nInRangeEnemy ~= nil
        and #nInRangeAlly >= #nInRangeEnemy
        then
            if not Impetus:GetAutoCastState()
            then
                Impetus:ToggleAutoCast()
                return BOT_ACTION_DESIRE_HIGH
            end
        end
    end

    if  J.IsFarming(bot)
    and nAbilityLevel == 4
    then
        local nNeutralCreeps = bot:GetNearbyNeutralCreeps(nAttackRange)

        if  nNeutralCreeps ~= nil and #nNeutralCreeps >= 1
        and J.IsValid(nNeutralCreeps[1])
        then
            if not Impetus:GetAutoCastState()
            then
                Impetus:ToggleAutoCast()
                return BOT_ACTION_DESIRE_HIGH
            end
        end
    end

    if Impetus:GetAutoCastState()
    then
        Impetus:ToggleAutoCast()
        return BOT_ACTION_DESIRE_HIGH
    end

    return BOT_ACTION_DESIRE_NONE
end

function X.ConsiderEnchant()
    if not Enchant:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    local nCastRange = Enchant:GetCastRange()
    local nMaxLevel = Enchant:GetSpecialValueInt('level_req')
    local nDamage = Enchant:GetSpecialValueInt('enchant_damage')
    local nDuration = Enchant:GetSpecialValueFloat('slow_duration')
	local nNeutralCreeps = bot:GetNearbyNeutralCreeps(nCastRange)
    local botTarget = J.GetProperTarget(bot)

    local nEnemyHeroes = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE)
    for _, enemyHero in pairs(nEnemyHeroes)
    do
        if  J.IsValidHero(enemyHero)
        and J.CanCastOnNonMagicImmune(enemyHero)
        and J.CanKillTarget(enemyHero, nDamage * nDuration, DAMAGE_TYPE_ALL)
        and not J.IsSuspiciousIllusion(enemyHero)
        then
            return BOT_ACTION_DESIRE_HIGH, enemyHero
        end
    end

    local nAllyHeroes = bot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE)
    for _, allyHero in pairs(nAllyHeroes)
    do
        local nAllyInRangeEnemy = allyHero:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE)

        if  J.IsRetreating(allyHero)
        and J.IsValidHero(nAllyInRangeEnemy[1])
        and not J.IsSuspiciousIllusion(nAllyInRangeEnemy[1])
        and not J.IsDisabled(nAllyInRangeEnemy[1])
        then
            if J.IsInRange(bot, nAllyInRangeEnemy[1], nCastRange)
            then
                return BOT_ACTION_DESIRE_HIGH, nAllyInRangeEnemy[1]
            end
        end
    end

    if J.IsGoingOnSomeone(bot)
    then
        local nInRangeAlly = bot:GetNearbyHeroes(nCastRange + 100, false, BOT_MODE_NONE)
        local nInRangeEnemy = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE)

        if  J.IsValidTarget(botTarget)
        and J.CanCastOnNonMagicImmune(botTarget)
        and J.IsInRange(bot, botTarget, nCastRange)
        and not J.IsSuspiciousIllusion(botTarget)
        and not botTarget:HasModifier('modifier_abaddon_borrowed_time')
        and not botTarget:HasModifier('modifier_faceless_void_chronosphere')
        and nInRangeAlly ~= nil and nInRangeEnemy ~= nil
        and ((#nInRangeAlly >= #nInRangeEnemy) or (#nInRangeEnemy > #nInRangeAlly and J.WeAreStronger(bot, nCastRange + 100)))
        then
            return BOT_ACTION_DESIRE_HIGH, botTarget
        end
    end

    local nGoodCreep = {
        "npc_dota_neutral_alpha_wolf",
        "npc_dota_neutral_centaur_khan",
        "npc_dota_neutral_polar_furbolg_ursa_warrior",
        "npc_dota_neutral_dark_troll_warlord",
        "npc_dota_neutral_satyr_hellcaller",
        "npc_dota_neutral_enraged_wildkin",
        "npc_dota_neutral_warpine_raider",
    }

    for _, creep in pairs(nNeutralCreeps)
    do
        if  J.IsValid(creep)
        and creep:GetLevel() <= nMaxLevel
        then
            for _, gCreep in pairs(nGoodCreep)
            do
                if creep:GetUnitName() == gCreep
                then
                    return BOT_ACTION_DESIRE_HIGH, creep
                end
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderNaturesAttendant()
    if not NaturesAttendant:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE
    end

    if J.IsRetreating(bot)
    then
        if  J.GetHP(bot) < 0.65
        and bot:DistanceFromFountain() > 800
        then
            return BOT_ACTION_DESIRE_HIGH
        end
    end

	return BOT_ACTION_DESIRE_NONE
end

function X.ConsiderSproink()
    if not Sproink:IsTrained()
    or not Sproink:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE
    end

    local nAttackRange = bot:GetAttackRange()

    local nAllyHeroes = bot:GetNearbyHeroes(nAttackRange + 100, false, BOT_MODE_NONE)
    local nEnemyHeroes = bot:GetNearbyHeroes(nAttackRange, true, BOT_MODE_NONE)
    local nImpetusMul = Impetus:GetSpecialValueFloat('value') / 100
    local botTarget = J.GetProperTarget(bot)

    for _, enemyHero in pairs(nEnemyHeroes)
    do
        if  J.IsValidHero(enemyHero)
        and J.CanKillTarget(enemyHero, nImpetusMul * GetUnitToUnitDistance(bot, enemyHero), DAMAGE_TYPE_PURE)
        and bot:IsFacingLocation(enemyHero:GetLocation(), 15)
        and not J.IsSuspiciousIllusion(enemyHero)
        and not enemyHero:HasModifier('modifier_abaddon_borrowed_time')
        and not enemyHero:HasModifier('modifier_dazzle_shallow_grave')
        then
            return BOT_ACTION_DESIRE_HIGH
        end
    end

    if J.IsGoingOnSomeone(bot)
    then
        if  J.IsValidTarget(botTarget)
        and bot:IsFacingLocation(botTarget:GetLocation(), 15)
        and not J.IsSuspiciousIllusion(botTarget)
        and not botTarget:HasModifier('modifier_abaddon_borrowed_time')
        and not botTarget:HasModifier('modifier_dazzle_shallow_grave')
        then
            return BOT_ACTION_DESIRE_HIGH
        end
    end

    if J.IsRetreating(bot)
    then
        if  nAllyHeroes ~= nil and nEnemyHeroes ~= nil
        and #nEnemyHeroes > #nAllyHeroes
        and J.IsValidHero(nEnemyHeroes[1])
        and bot:IsFacingLocation(nEnemyHeroes[1]:GetLocation(), 30)
        and not J.IsSuspiciousIllusion(nEnemyHeroes[1])
        then
            return BOT_ACTION_DESIRE_HIGH
        end
    end

    return BOT_ACTION_DESIRE_NONE
end

function X.ConsiderLittleFriends()
    if not LittleFriends:IsTrained()
    or not LittleFriends:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    local nCastRange = LittleFriends:GetCastRange()
    local nRadius = LittleFriends:GetSpecialValueInt('radius')
    local nDuration = LittleFriends:GetSpecialValueInt('duration')

    local nEnemyHeroes = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE)
    for _, enemyHero in pairs(nEnemyHeroes)
    do
        if  J.IsValidHero(enemyHero)
        and J.GetHP(enemyHero) < 0.33
        and not J.IsSuspiciousIllusion(enemyHero)
        and not enemyHero:HasModifier('modifier_abaddon_borrowed_time')
        and not enemyHero:HasModifier('modifier_faceless_void_chronosphere')
        then
            bot:SetTarget(enemyHero)
            return BOT_ACTION_DESIRE_HIGH, enemyHero
        end
    end

    if J.IsGoingOnSomeone(bot, 1200)
    then
        local botTarget = J.GetStrongestUnit(nCastRange, bot, true, false, nDuration)
        local nTargetInRangeEnemy = botTarget:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE)
        local nInRangeAlly = bot:GetNearbyHeroes(nCastRange + 150, false, BOT_MODE_NONE)
        local nInRangeEnemy = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE)

        if  J.IsValidTarget(botTarget)
        and nInRangeAlly ~= nil and nInRangeEnemy
        and #nInRangeAlly >= #nInRangeEnemy
        and #nTargetInRangeEnemy >= 1
        and not J.IsSuspiciousIllusion(botTarget)
        and not botTarget:HasModifier('modifier_abaddon_borrowed_time')
        and not botTarget:HasModifier('modifier_faceless_void_chronosphere')
        then
            return BOT_ACTION_DESIRE_HIGH, botTarget
        end
    end

    if J.IsRetreating(bot)
    then
        local nInRangeAlly = bot:GetNearbyHeroes(nCastRange + 150, false, BOT_MODE_NONE)
        local nInRangeEnemy = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE)

        if  nInRangeAlly ~= nil and nInRangeEnemy ~= nil
        and #nInRangeEnemy > #nInRangeAlly
        and J.IsValidHero(nInRangeEnemy[1])
        and J.IsInRange(bot, nInRangeEnemy[1], nCastRange)
        and not J.IsSuspiciousIllusion(nInRangeEnemy[1])
        then
            return BOT_ACTION_DESIRE_HIGH, nInRangeEnemy[1]
        end
    end

    if J.IsDoingRoshan(bot)
    then
        local botTarget = bot:GetAttackTarget()

        if  J.IsRoshan(botTarget)
        and J.CanCastOnNonMagicImmune(botTarget)
        and J.IsInRange(bot, botTarget, nCastRange)
        then
            return BOT_ACTION_DESIRE_HIGH, botTarget
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil
end

return X