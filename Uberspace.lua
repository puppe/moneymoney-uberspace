--[[
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
--]]

WebBanking{version = 1.00,
           url = 'https://uberspace.de/login',
           services = {'Uberspace.de'}}

function SupportsBank (protocol, bankCode)
  return bankCode == 'Uberspace.de' and protocol == ProtocolWebBanking
end

local usConnection = Connection()
local usUsername

function InitializeSession (protocol, bankCode, username, username2,
                            password, username3)
  -- Login.
  usUsername = username

  html = HTML(usConnection:get('https://uberspace.de/login'))
  html:xpath('//input[@name="login"]'):attr('value', username)
  html:xpath('//input[@name="password"]'):attr('value', password)

  html = HTML(
    usConnection:request(html:xpath('//input[@name="submit"]'):click()))
  if html:xpath('//input[@name="login"]'):length() > 0 then
    -- We are still at the login screen.
    return "Failed to log in. Please check your user credentials."
  end
end

function ListAccounts (knownAccounts)
  -- Return array of accounts.
  local account = {
    name = 'Uberspace ' .. usUsername,
    accountNumber = '1',
    portfolio = false,
    currency = 'EUR',
    type = AccountTypeSavings
  }
  return {account}
end

function RefreshAccount (account, since)
  function ParseAmount (amountString)
    local pattern = '(%-?%d+),(%d%d)'
    local euro, cent = amountString:match(pattern)
    euro = tonumber(euro)
    cent = tonumber(cent) / 100
    if euro < 0 then
      return euro - cent
    else
      return euro + cent
    end
  end

  html = HTML(usConnection:get(
                'https://uberspace.de/dashboard/accounting'))
  tableRows = html:xpath(
    '//*[@id="transactions"]//tr[count(td)=3][position()<last()]')
  print('Found ' .. tableRows:length() .. ' rows')

  local transactions = {}

  for i = 1, tableRows:length() do
    local row = tableRows:get(i)
    local children = row:children()
    local pattern = '(%d%d)%.(%d%d)%.(%d%d%d%d)'
    local day, month, year = children:get(1):text():match(pattern)
    local valueTime = os.time{day=day, month=month, year=year}

    if valueTime < since then
      print('Stopping parsing because transaction is too old.')
      print('Date of transaction: ' .. os.date('%c', valueTime))
      print('since: ' .. os.date('%c', since))
      break
    end

    local amount = ParseAmount(children:get(3):text())
    table.insert(transactions, {
                   bookingDate = valueTime,
                   amount = amount
    })
  end

  balanceElement = html:xpath('//*[@id="total"]')
  balance = ParseAmount(balanceElement:text())
  return {balance=balance, transactions=transactions}
end

function EndSession ()
  usConnection:get('https://uberspace.de/logout')
end
