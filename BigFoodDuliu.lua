local _
local _G = _G
BigFoodDuliu = LibStub("AceAddon-3.0"):NewAddon("BigFoodDuliu", "AceEvent-3.0", "AceHook-3.0")

SLASH_BigFoodDuliu1 = "/bfd"
local GetUnitName = GetUnitName

--参数配置-----
local DEBUG_MORE = false
local DEBUG_MORE2 = false

local EAT_MAX_TIME = 30 --- 食物倒计时最大 秒

local EAT_TO_BUFF_TIME = 10  --- 食物吃出buff需要的时间 秒

local RE_EAT_BUFF_TIME = 55 --- 食物BUFF大于这个分钟，就表示吃了还TM吃;小于这个认为他可以吃

local FOOD_EAT_ID = 192002 --大餐吃的ID

-- 大餐buFF IDs
local BIG_FOOD_BUFF_IDS = {
	["STRENGTH"] = 201638, --力量
	["STAMINA"] = 201639, --耐力
	["INTELLECT"] = 201640, --智力
	["AGILITY"] = 201641 --敏捷
}
-- 个人食物BUFF IDS. 如果FOOD_EAT_ID一致, BUFF不一致,就得追加
local SELF_FOOD_BUFF_IDS = {
	["CRITICAL"] = 225602, --  暴击食物
	["MASTERY"] = 225604, --  精通食物
	["VERSATILITY"] = 225605, --  全能食物
	["HASTE"] = 225603, -- 急速食物
	["FIGHT"] = 201695, -- 斗士食物
}
------end

--[[
----参数配置 DEBUG-----
local DEBUG_MORE = true
local DEBUG_MORE2 = false

local EAT_MAX_TIME = 20 --- 食物倒计时最大 秒

local EAT_TO_BUFF_TIME = 10  --- 食物吃出buff需要的时间 秒

local RE_EAT_BUFF_TIME = 55 --- 食物BUFF大于这个分钟，就表示吃了还TM吃;小于这个认为他可以吃

local FOOD_EAT_ID = 225743 --法罗纳尔气泡酒的 225743

-- 当前是法罗纳尔气泡酒的ID 201334 -- 
local BIG_FOOD_BUFF_IDS = {
	["STRENGTH"] = 201334, --力量
	["STAMINA"] = 201334, --耐力
	["INTELLECT"] = 201334, --智力
	["AGILITY"] = 201334 --敏捷
}

local SELF_FOOD_BUFF_IDS = {
	["CRITICAL"] = 225602, --  暴击食物
	["MASTERY"] = 225604, --  精通食物
	["VERSATILITY"] = 225605, --  全能食物
	["HASTE"] = 225603, -- 急速食物
	["FIGHT"] = 201695, -- 斗士食物
}
--]]
------end

local EAT_ALMOST_MAX = 3540

local IS_REGISGER = false
local string_format = string.format

local InfoList

local function isSpellEqual(sid)
	for k, v in pairs(BIG_FOOD_BUFF_IDS) do
		if v == sid then return 1 end
	end
	for k, v in pairs(SELF_FOOD_BUFF_IDS) do
		if v == sid then return 2 end
	end
	return 0
end

local function registerMyEvents(event, ...)
	if IS_REGISGER == true then return end
	if BFD_Enable == nil then
		BFD_Enable = true
    end
	
	InfoList = {}
	if BFD_Enable == true then
		BigFoodDuliu:RegisterEvent("PLAYER_REGEN_ENABLED")
		BigFoodDuliu:RegisterEvent("PLAYER_REGEN_DISABLED")
		BigFoodDuliu:RegisterEvent("UNIT_AURA")
		IS_REGISGER = true
	end
end

function BigFoodDuliu:OnEnable()
	IS_REGISGER = false
	BigFoodDuliu:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function BigFoodDuliu:PLAYER_ENTERING_WORLD()
	registerMyEvents()
end

function BigFoodDuliu:PLAYER_REGEN_ENABLED()
	if DEBUG_MORE then print("战斗结束!开始监控。") end
	if BFD_Enable then BigFoodDuliu:RegisterEvent("UNIT_AURA") end
end

function BigFoodDuliu:PLAYER_REGEN_DISABLED()
	if DEBUG_MORE then print("战斗开始!停止监控。") end
	BigFoodDuliu:UnregisterEvent("UNIT_AURA")
	InfoList = {}
end

function BigFoodDuliu:UNIT_AURA(self, ...)
	local unitid = ...
	local curTime = GetTime()
	if unitid == nil then return end
	local name = GetUnitName(unitid)
	if InfoList[name] then
		if curTime <= InfoList[name].timeStamp + 0.01 then
			if DEBUG_MORE2 then print(name.."刷新太快减少计算return") end
			return
		end
		InfoList[name].timeStamp = curTime
	end
	local leftBufTime = 0
	local leftEatTime = -1
	local buffType = 0
	local hasEating = false

	for j=1,40 do
		local _, _, _, _, _, _, expirationTime, _, _, _, spellID = UnitBuff(unitid, j)
		if expirationTime then
			if spellID == FOOD_EAT_ID then
				hasEating = true
				leftEatTime = expirationTime - curTime
				if buffType > 0 then break end
			else
				buffType = isSpellEqual(spellID)
				if buffType > 0 then
					leftBufTime = expirationTime - curTime
					if hasEating == true then break end
				end
			end
		end
	end
	if DEBUG_MORE2 then print(name..",Buff "..(buffType).." Eating "..tostring(hasEating).." bufleft " ..string_format("%.0f", leftBufTime).." eatTime "..string_format("%.1f", leftEatTime)) end
	if DEBUG_MORE2 then print("curTime "..curTime) end
	if InfoList[name] == nil then
		if hasEating == true then
			--刚进入进食的状态,
			if InfoList[name] == nil then
				InfoList[name] = {
				flag=0,
				eatToBuffTime=0,
				totalTime=0,
				lastEatDaoTime=0,
				buffLeftTime=0,
				eatCount=0,
				timeStamp=curTime,
				}
			end

			if buffType > 0 then
				InfoList[name].buffLeftTime = leftBufTime
				if (leftBufTime/60) >= RE_EAT_BUFF_TIME then
					print(name..(">毒瘤>有BUFF").. string_format("%.0f", (leftBufTime/60)).."分钟还吃！") --W
				end
			else
				if DEBUG_MORE2 then print(name.."开始吃") end
			end
			InfoList[name].eatCount = 1
			InfoList[name].flag = 1 --开始
			InfoList[name].eatToBuffTime = curTime
			InfoList[name].totalTime = curTime
			InfoList[name].lastEatDaoTime = leftEatTime
		else
			--没有信息，证明没开始吃同时没有进食 或者 有buff了，但是没吃。不管是否有buff
			--print("无用信息") --DEBUG
		end
	else -- 说明已经开始吃这个动作已经做了，这次是在更新
		if hasEating == true and buffType > 0 then
			-- 在进食, 而有食物buff 应该是吃出buff了或者之前就是有了的
			if buffType == 1 then
				--print(name.."上次就有BUFF，保存剩余"..InfoList[name].lastEatDaoTime.." 现在剩余"..leftEatTime)
				if leftEatTime > InfoList[name].lastEatDaoTime then
					InfoList[name].eatCount = InfoList[name].eatCount + 1
					print(name..">>毒瘤有大餐buff TMD又吃，总计"..InfoList[name].eatCount.."次") --W
				end
				InfoList[name].lastEatDaoTime = leftEatTime
			elseif buffType == 2 then
				--print(name.."上次就有BUFF，保存剩余"..InfoList[name].lastEatDaoTime.." 现在剩余"..leftEatTime)
				if leftEatTime > InfoList[name].lastEatDaoTime then
					InfoList[name].eatCount = InfoList[name].eatCount + 1
					print(name..">>坑自己,有属性buff 又吃，总计"..InfoList[name].eatCount.."次") --W
				end
				InfoList[name].lastEatDaoTime = leftEatTime
			end
		elseif hasEating == true and buffType == 0 then
			--- 正在吃,还没buff,刷新
			--print(name.."正在进食，no BUFF"..InfoList[name].lastEatDaoTime.." 现在剩余"..leftEatTime)
			if leftEatTime > InfoList[name].lastEatDaoTime then
				InfoList[name].eatCount = InfoList[name].eatCount + 1
				print(name..">毒瘤>还没吃出BUFF又吃，共计"..InfoList[name].eatCount.."次") --W
				print("   (无法区分吃的自带食物还是大餐)")
			end
			InfoList[name].lastEatDaoTime = leftEatTime
		elseif hasEating == false and buffType > 0 then
			--- 已经吃完 (或者 已经有buff,没吃这种情况，由于没吃就不会有Info，就不会到这里来，所以只有已经吃完的情况)
			local totalt = curTime - InfoList[name].totalTime;
			--InfoList[name].totalTime = totalt
			-- InfoList[name].buffLeftTime = leftBufTime
			if totalt > EAT_MAX_TIME + 0.1 then
				if buffType == 1 then
					print(name..">毒瘤>停止进食大餐超时！耗时"..string_format("%.1f", totalt).."秒") --W
				elseif buffType == 2 then
					print(name.."坑自己，停止吃自带食物超时！耗时"..string_format("%.1f", totalt).."秒") --W
				end
			elseif totalt < EAT_TO_BUFF_TIME - 0.1 and leftBufTime < EAT_ALMOST_MAX then
				if buffType == 1 then
					print(name..">毒瘤>停止进食大餐, 耗时"..string_format("%.1f", totalt).."秒过短，buff没刷新。")
				elseif buffType == 2 then
					print(name.."坑自己，停止吃自带食物, 耗时"..string_format("%.1f", totalt).."秒过短，buff没刷新。")
				end
			else
				if DEBUG_MORE then print(name.."停止进食，耗时"..string_format("%.1f", totalt).."秒") end
				if InfoList[name].eatCount > 1 then
					local strname = ">毒瘤>大餐"
					if buffType == 2 then strname = "自带食物" end
					print(name.."停止进食"..strname.."，耗时"..string_format("%.1f", totalt).."秒,共计"..InfoList[name].eatCount.."次")
				end
			end
			InfoList[name] = nil
		elseif hasEating == false and buffType == 0 then
			---没吃出BUFF停止了。（或者没吃没buff的状态。跟上面一下，有Info的情况只会是从有状态进入的不会进来的。所以是没吃出BUFF停止了。）
			local totalt = curTime - InfoList[name].totalTime;
			-- InfoList[name].totalTime = totalt
			print(name..">毒瘤>没吃出buff！耗时"..string_format("%.1f", totalt).."秒") --W
			print("   (无法区分吃的自带食物还是大餐)")
			InfoList[name] = nil
		end
	end
end

function SlashCmdList.BigFoodDuliu(msg)
	if msg == "" or msg == "HELP" or msg == "help" then
		print(">>>>大餐毒瘤插件 进入战斗会自动临时禁用，节约内存。")
		print("请输入/bfd enable开启, /bfd disable关闭")
		print("当前启用状态是: "..tostring(BFD_Enable))
	elseif msg == "enable" then
		print("bfd 开启")
		BFD_Enable = true
		BigFoodDuliu:RegisterEvent("UNIT_AURA")
	elseif msg == "disable" then
		print("bfd 关闭")
		BFD_Enable = false
		BigFoodDuliu:UnregisterEvent("UNIT_AURA")
	elseif msg == "maid_enable" then
		BFD_Maid_Enable = true
		BigFoodDuliu:RegisterEvent("UNIT_AURA")
	elseif msg == "maid_disable" then
		BFD_Maid_Enable = false
		BigFoodDuliu:UnregisterEvent("UNIT_AURA")
	end
end