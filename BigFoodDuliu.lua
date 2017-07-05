local _
local _G = _G
BigFoodDuliu = LibStub("AceAddon-3.0"):NewAddon("BigFoodDuliu", "AceEvent-3.0", "AceHook-3.0")

SLASH_BigFoodDuliu1 = "/bfd"

local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local GetNamePlates = C_NamePlate.GetNamePlates
local UnitName, GetUnitName = UnitName, GetUnitName

----参数配置-----
local DEBUG_MORE = true
local DEBUG_MORE2 = false

local EAT_MAX_TIME = 30 --- 食物倒计时最大 秒

local EAT_TO_BUFF_TIME = 10  --- 食物吃出buff需要的时间 秒

local HALF_TOTAL_BUFF_TIME = 30 --- 食物BUFF大于这个分钟，就表示吃了还TM吃

--吃食物的ID
local FOOD_EAT_ID = 225743 --法罗纳尔气泡酒的ID。 大餐吃的ID忘记了。 

-- 食物buFF的ID，由于大餐有4个职业的bUFF，所以预留4个
-- 备注的是大餐的4个职业的BUFF ID 当前是法罗纳尔气泡酒的ID201334 -- 
local FOOD_BUF_ID0 = 201638 --201334 --
local FOOD_BUF_ID1 = 201641 --201334 -- 
local FOOD_BUF_ID2 = 201639 --201334 -- 
local FOOD_BUF_ID3 = 201640 --201334 -- 
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
	if DEBUG_MORE then print("停止!停止监控。") end
	if BFD_Enable then BigFoodDuliu:RegisterEvent("UNIT_AURA") end
end

function BigFoodDuliu:PLAYER_REGEN_DISABLED()
	if DEBUG_MORE then print("战斗!开始监控。") end
	BigFoodDuliu:UnregisterEvent("UNIT_AURA")
	AInfoList = {}
end

function BigFoodDuliu:UNIT_AURA(self, ...)
	local unitid = ...
	if unitid == nil then return end
	local leftTime = 0
	local leftEatTime = -1
	local hasBuff = false
	local hasEating = false
	local name = GetUnitName(unitid)
	local curTime = GetTime()
	for j=1,40 do
		local _, _, _, _, _, _, expirationTime, _, _, _, spellID = UnitBuff(unitid, j)
		if expirationTime then
			if spellID == FOOD_EAT_ID then
				hasEating = true
				leftEatTime = expirationTime - curTime
				if hasBuff == true then break end
			elseif isSpellEqual(spellID) then
				hasBuff = true
				leftTime = expirationTime - curTime
				if hasEating == true then break end
			end
		end
	end
	-- if DEBUG_MORE2 then print(name..",Buff "..tostring(hasBuff).." Eating "..tostring(hasEating).." bfleft " ..string_format("%.0f", leftTime).." eatTime "..string_format("%.1f", leftEatTime)) end
	-- if DEBUG_MORE2 then print("curTime "..curTime) end
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
				timeStamp=curTime,
				}
			end
			if hasBuff == true then
				AInfoList[name].isLastHas = true
				if (leftTime/60) > HALF_TOTAL_BUFF_TIME then
					print(name..(">毒瘤>有BUFF").. string_format("%.0f", (leftTime/60)).."分钟还吃！") --W
				end
			else
				if DEBUG_MORE2 then print(name.."开始吃") end
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
		
		if hasEating == true and hasBuff == true then
			-- 在进食, 而有食物buff 应该是吃出buff了或者之前就是有了的
			AInfoList[name].timeStamp = curTime
			if AInfoList[name].isLastHas == true then
				--print(name.."上次就有BUFF，保存剩余"..AInfoList[name].lastEatDaoTime.." 现在剩余"..leftEatTime)
				if leftEatTime > AInfoList[name].lastEatDaoTime then
					print(name..">>毒瘤有buff，又TM吃1次。总计2次。") --W
				end
				AInfoList[name].lastEatDaoTime = leftEatTime
			else
				if AInfoList[name].flag == 1 then
					local tempT = curTime - AInfoList[name].eatToBuffTime;
					AInfoList[name].eatToBuffTime = tempT
					AInfoList[name].flag = 2 --吃出了buff阶段
					if DEBUG_MORE then print(name.."吃出buff时间，耗时"..string_format("%.1f", tempT).."秒; ") end-- W
					if (tempT < (EAT_TO_BUFF_TIME - 0.2)) or (tempT > (EAT_TO_BUFF_TIME + 0.1)) then
						print(name..">毒瘤>吃出buff时间异常，耗时"..string_format("%.1f", tempT).."秒; ") -- W
					end
				elseif AInfoList[name].flag == 2 then
					--print(name.."吃出了buff，保存剩余"..AInfoList[name].lastEatDaoTime.." 现在剩余"..leftEatTime)
					if leftEatTime > AInfoList[name].lastEatDaoTime then
						print(name..">毒瘤>吃出了BUFF以后，又TM吃了1次。") --W
					end
					AInfoList[name].lastEatDaoTime = leftEatTime
				end
			end
		elseif hasEating == true and hasBuff == false then
			AInfoList[name].timeStamp = curTime
			--- 正在吃,还没buff
			--print(name.."正在进食，no BUFF"..AInfoList[name].lastEatDaoTime.." 现在剩余"..leftEatTime)
			if leftEatTime > AInfoList[name].lastEatDaoTime then
				print(name..">>毒瘤<<还没吃出BUFF，又TM吃了1次。") --W			
			end
			AInfoList[name].lastEatDaoTime = leftEatTime
		elseif hasEating == false and hasBuff == true then
			if curTime <= AInfoList[name].timeStamp then --这个是因为扫描buff导致的时间差异
				if DEBUG_MORE2 then print("没吃食物的计算时间比下一次来的晚return1。"..name) end
				return
			end
			AInfoList[name].timeStamp = curTime
			--- 已经吃完 或者 已经有buff,没吃(这种情况，由于没吃就不会有Info，就不会到这里来，所以只有已经吃完的情况)
			local totalt = curTime - AInfoList[name].totalTime;
			AInfoList[name].totalTime = totalt
			if totalt > EAT_MAX_TIME + 0.2 then
				print(name..">毒瘤>停止进食超时！耗时"..string_format("%.1f", totalt).."秒;") --W
			else
				if DEBUG_MORE then print(name.."停止进食, 耗时"..string_format("%.1f", totalt).."秒;") end--W
			end
			AInfoList[name] = nil
		elseif hasEating == false and hasBuff == false then
			if curTime <= AInfoList[name].timeStamp then  --这个是因为扫描buff导致的时间差异
				if DEBUG_MORE2 then print("没吃食物的计算时间比下一次来的晚return2。"..name) end
				return
			end
			AInfoList[name].timeStamp = curTime
			---没吃出BUFF停止了。或者没吃没buff的状态。跟上面一下，有Info的情况只会是从有状态进入的不会进来的。所以是没吃出BUFF停止了。
			local totalt = curTime - AInfoList[name].totalTime;
			AInfoList[name].totalTime = totalt
			print(name..">毒瘤>没吃出buff！耗时"..string_format("%.1f", totalt).."秒;") --W
			AInfoList[name] = nil
		end
	end
end

local function trim(s) return (string.gsub(s, "^%s*(.-)%s*$", "%1"))end

function SlashCmdList.BigFoodDuliu(msg)
	if msg == "" or msg == "HELP" or msg == "help" then
		print(">>>>大餐毒瘤插件")
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
	end
end