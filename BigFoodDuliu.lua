local _
local _G = _G
BigFoodDuliu = LibStub("AceAddon-3.0"):NewAddon("BigFoodDuliu", "AceEvent-3.0", "AceHook-3.0")

SLASH_BigFoodDuliu1 = "/bfd"

local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local GetNamePlates = C_NamePlate.GetNamePlates
local UnitName, GetUnitName = UnitName, GetUnitName

----参数配置flag
local EAT_MAX_TIME = 20

local EAT_TO_BUFF_TIME = 10

local HALF_TOTAL_BUFF_TIME = 30


local FOOD_EAT_ID = 225743

local FOOD_BUF_ID0 = 201334 -- 201638
local FOOD_BUF_ID1 = 201334 -- 201641
local FOOD_BUF_ID2 = 201334 -- 201639
local FOOD_BUF_ID3 = 201334 -- 201640
------end

local string_find = string.find
local string_format = string.format

local IsCombat = false

local AInfoList
local stackInfoList


local function isSpellEqual(sid)
	if sid == FOOD_BUF_ID0 or sid == FOOD_BUF_ID1 or sid == FOOD_BUF_ID2 or sid == FOOD_BUF_ID3 then
		return true
	end
	return false
end

local function registerMyEvents(event, ...)
	if IS_REGISGER == true then return end
	if BFD_Enable == nil then
		BFD_Enable = true
    end

	AInfoList = {}
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
	--print("停止!")
	if BFD_Enable then BigFoodDuliu:RegisterEvent("UNIT_AURA") end
end

function BigFoodDuliu:PLAYER_REGEN_DISABLED()
	--print("战斗!")
	BigFoodDuliu:UnregisterEvent("UNIT_AURA")
	AInfoList = {}
end

function BigFoodDuliu:UNIT_AURA(self, ...)
	local unitid = ...
	if unitid == nil then return end
	local leftTime = 0
	local leftEatTime = EAT_MAX_TIME
	local hasFood = false
	local hasEating = false
	local name = GetUnitName(unitid)
	local curTime = GetTime()
	for j=1,40 do
		local name, _, _, _, _, duration, expirationTime, unitCaster, _, _, spellID = UnitBuff(unitid, j)
		if unitCaster and expirationTime and unitCaster == unitid then
			if spellID == FOOD_EAT_ID then
				hasEating = true
				leftEatTime = expirationTime - curTime
				if hasFood == true then break end
			elseif isSpellEqual(spellID) then
				hasFood = true
				leftTime = expirationTime - curTime
				if hasEating == true then break end
			end
		end
	end
	--print("Food "..tostring(hasFood).." Eat "..tostring(hasEating).." nm "..name.." bfleft " ..leftTime.." eatTime "..leftEatTime)
	if AInfoList[name] == nil then
		if hasEating == true then
			--刚进入进食的状态,
			if AInfoList[name] == nil then
				AInfoList[name] = {
				flag=0,
				eatToBuffTime=0,
				totalTime=0,
				lastEatDaoTime=0,
				isLastHas=false,
				}
			end
			if hasFood == true then
				AInfoList[name].isLastHas = true
				if (leftTime/60) > HALF_TOTAL_BUFF_TIME then
					print(name..(">>有BUFF还吃,BUFF剩余时间").. string_format("%.0f", (leftTime/60)).."分钟；") --W
				end
			else
				-- print(name.."开始吃; ")--W
			end
			
			AInfoList[name].flag = 1 --开始
			AInfoList[name].eatToBuffTime = curTime
			AInfoList[name].totalTime = curTime
			AInfoList[name].lastEatDaoTime = leftEatTime
		else
			--没有信息，证明没开始吃同时没有进食 或者 有buff了，但是没吃。不管是否有buff
			--print("无用信息") --DEBUG
		end
	else -- 说明已经开始吃这个动作已经做了，这次是在更新
		if hasEating == true and hasFood == true then
			-- 在进食, 而有食物buff 应该是吃出buff了或者之前就是有了的
			if AInfoList[name].isLastHas == true then
				--print(name..">>上次就有BUFF，保存剩余"..AInfoList[name].lastEatDaoTime.." 现在剩余"..leftEatTime)
				if leftEatTime > AInfoList[name].lastEatDaoTime then
					print(name..">><<上次有buff了，又TM吃了1次。") --W
				end
				AInfoList[name].lastEatDaoTime = leftEatTime
			else
				if AInfoList[name].flag == 1 then
					local tempT = curTime - AInfoList[name].eatToBuffTime;
					AInfoList[name].eatToBuffTime = tempT
					AInfoList[name].flag = 2 --吃出了buff阶段
					print(name..">>吃出buff时间异常，耗时"..string_format("%.1f", tempT).."秒; ") -- W
					if (tempT < (EAT_TO_BUFF_TIME - 0.2)) or (tempT > (EAT_TO_BUFF_TIME + 0.2)) then
						print(name..">>吃出buff时间异常，耗时"..string_format("%.1f", tempT).."秒; ") -- W
					end
				elseif AInfoList[name].flag == 2 then
					--print(name.."吃出buff，继续吃BUFF剩余时间"..string_format("%.0f", leftEatTime).."秒; ") -- debug
					--print(name.."吃出了buff，保存剩余"..AInfoList[name].lastEatDaoTime.." 现在剩余"..leftEatTime)
					if leftEatTime > AInfoList[name].lastEatDaoTime then
						print(name..">>吃出了BUFF以后，又TM吃了1次。") --W
					end
					AInfoList[name].lastEatDaoTime = leftEatTime
				end
			end
		elseif hasEating == true and hasFood == false then
			--- 正在吃,还没buff
			--print(name.."正在进食，no BUFF"..AInfoList[name].lastEatDaoTime.." 现在剩余"..leftEatTime)
			if leftEatTime > AInfoList[name].lastEatDaoTime then
				print(name..">><<还没吃出BUFF，又TM吃了1次。") --W			
			end
			AInfoList[name].lastEatDaoTime = leftEatTime
		elseif hasEating == false and hasFood == true then
			--- 已经吃完 或者 已经有buff,没吃(这种情况，由于没吃就不会有Info，就不会到这里来，所以只有已经吃完的情况)
			local totalt = curTime - AInfoList[name].totalTime;
			AInfoList[name].totalTime = totalt
			if totalt > EAT_MAX_TIME + 0.3 then
				print(name..">>停止进食超时毒瘤！耗时"..string_format("%.1f", totalt).."秒;") --W
			else
				-- print(name.."停止进食, 耗时"..string_format("%.1f", totalt).."秒;") --W
			end
			AInfoList[name] = nil
		elseif hasEating == false and hasFood == false then
			---没吃出BUFF停止了。或者没吃没buff的状态。跟上面一下，有Info的情况只会是从有状态进入的不会进来的。所以是没吃出BUFF停止了。
			local totalt = curTime - AInfoList[name].totalTime;
			AInfoList[name].totalTime = totalt
			print(name..">>没吃出buff！耗时"..string_format("%.1f", totalt).."秒;") --W
			AInfoList[name] = nil
		end
	end
end

local function trim(s) return (string.gsub(s, "^%s*(.-)%s*$", "%1"))end

function SlashCmdList.BigFoodDuliu(msg)
	if msg == "" or msg == "HELP" or msg == "help" then
		print("请输入/bfd enable开启, /bfd disable关闭")
		print("当前启用状态是: "..tostring(BFD_Enable))
	elseif msg == "show" then
	elseif msg == "clear" then
	elseif msg == "enable" then
		print("bfd 开启")
		BFD_Enable = true
		BigFoodDuliu:RegisterEvent("UNIT_AURA")
	elseif msg == "disable" then
		print("bfd 关闭")
		BFD_Enable = false
		BigFoodDuliu:UnregisterEvent("UNIT_AURA")
	end
end