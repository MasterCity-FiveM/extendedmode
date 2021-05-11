ESX.StartPayCheck = function()
	function payCheck()
		local xPlayers = ESX.GetPlayers()

		for i=1, #xPlayers, 1 do
			local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
			local job     = xPlayer.job.grade_name
			local salary  = xPlayer.job.grade_salary
			if salary > 0 then
				if job == 'unemployed' then -- unemployed
					xPlayer.addAccountMoney('bank', salary)
					TriggerClientEvent('esx:showAdvancedNotification', xPlayer.source, _U('bank'), _U('received_paycheck'), _U('received_help', salary), 'CHAR_BANK_MAZE', 9)
				else -- generic job
					ESX.TriggerServerCallback("esx_service:isPlayerInService", xPlayer.source, function(isInService)
						if isInService then
							xPlayer.addAccountMoney('bank', salary)
							TriggerClientEvent('esx:showAdvancedNotification', xPlayer.source, _U('bank'), _U('received_paycheck'), _U('received_salary', salary), 'CHAR_BANK_MAZE', 9)
						elseif xPlayer.get('aduty') then
							salary = 300
							xPlayer.addAccountMoney('bank', salary)
							TriggerClientEvent('esx:showAdvancedNotification', xPlayer.source, _U('bank'), _U('received_paycheck'), _U('received_salary', salary), 'CHAR_BANK_MAZE', 9)
						end
					end, xPlayer.source, xPlayer.job.name)
				end
			else
				if xPlayer.get('aduty') then
					salary = 300
					xPlayer.addAccountMoney('bank', salary)
					TriggerClientEvent('esx:showAdvancedNotification', xPlayer.source, _U('bank'), _U('received_paycheck'), _U('received_salary', salary), 'CHAR_BANK_MAZE', 9)
				end
			end
		end
		
		SetTimeout(Config.PaycheckInterval, payCheck)
	end
	
	function BankPayment()
		local xPlayers = ESX.GetPlayers()

		for i=1, #xPlayers, 1 do
			local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
			local bankMoney  = xPlayer.getAccount('bank').money
			if bankMoney > 0 then
				MoneyMustAdd = math.ceil(bankMoney / 99)
				xPlayer.addAccountMoney('bank', MoneyMustAdd)
				TriggerClientEvent('esx:showAdvancedNotification', xPlayer.source, _U('bank'), 'Soode Banki', 'Shoma ~g~' .. MoneyMustAdd .. '$~s~ sood seporde gozari daryaft kardid.', 'CHAR_BANK_MAZE', 9)
			end
		end
		
		SetTimeout(Config.DepositInterval, BankPayment)
	end

	SetTimeout(Config.PaycheckInterval, payCheck)
	SetTimeout(Config.DepositInterval, BankPayment)
end
