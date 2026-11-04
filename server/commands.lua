local function joinArgs(args, startIndex)
  local parts = {}
  for index = startIndex, #args do parts[#parts + 1] = args[index] end
  return table.concat(parts, ' ')
end

local function notify(sourceId, message, kind)
  TriggerClientEvent('mz_warns:client:notify', sourceId, {
    message = tostring(message or ''),
    type = kind or 'inform'
  })
end

RegisterCommand(Config.Commands.Issue, function(sourceId, args)
  if sourceId <= 0 then return end
  local targetSource = tonumber(args[1])
  local reason = joinArgs(args, 2)
  if not targetSource or #reason < 3 then
    return notify(sourceId, Config.Messages.UsageIssue, 'error')
  end
  local response = MZWarns.API.Issue(sourceId, targetSource, reason, 'mz_warns')
  if response.ok ~= true then
    return notify(sourceId, 'Advertencia negada: ' .. tostring(response.error), 'error')
  end
  notify(sourceId, string.format(
    Config.Messages.Issued,
    response.data.warning.publicId
  ), 'success')
end, false)

RegisterCommand(Config.Commands.List, function(sourceId, args)
  if sourceId <= 0 then return end
  local targetSource = tonumber(args[1])
  if not targetSource then return notify(sourceId, Config.Messages.UsageList, 'error') end
  local response = MZWarns.API.List(sourceId, {
    targetSource = targetSource,
    page = 1,
    pageSize = 10
  }, 'mz_warns')
  if response.ok ~= true then
    return notify(sourceId, 'Consulta negada: ' .. tostring(response.error), 'error')
  end
  local items = response.data.items or {}
  if #items == 0 then return notify(sourceId, 'Nenhuma advertencia encontrada.', 'inform') end
  local lines = { ('Advertencias encontradas: %d'):format(response.data.total or #items) }
  for _, warning in ipairs(items) do
    lines[#lines + 1] = ('%s | ACCOUNT:%s | CHAR:%s | %s | %s'):format(
      tostring(warning.publicId),
      tostring(warning.accountId or 'indisponivel'),
      tostring(warning.characterId or 'indisponivel'),
      tostring(warning.status),
      tostring(warning.reason)
    )
  end
  notify(sourceId, table.concat(lines, '\n'), 'inform')
end, false)

RegisterCommand(Config.Commands.Revoke, function(sourceId, args)
  if sourceId <= 0 then return end
  local publicId = args[1]
  local reason = joinArgs(args, 2)
  if not publicId or #reason < 3 then
    return notify(sourceId, Config.Messages.UsageRevoke, 'error')
  end
  local response = MZWarns.API.Revoke(sourceId, publicId, reason, 'mz_warns')
  if response.ok ~= true then
    return notify(sourceId, 'Revogacao negada: ' .. tostring(response.error), 'error')
  end
  notify(sourceId, string.format(
    Config.Messages.Revoked,
    response.data.warning.publicId
  ), 'success')
end, false)
