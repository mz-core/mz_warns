local function notify(message, kind)
  if GetResourceState('mz_menu') == 'started' then
    exports['mz_menu']:Notify(tostring(message or ''), kind or 'inform')
    return
  end
  TriggerEvent('chat:addMessage', {
    color = kind == 'error' and { 255, 100, 100 } or { 255, 190, 70 },
    args = { 'Advertencias', tostring(message or '') }
  })
end

RegisterNetEvent('mz_warns:client:notify', function(payload)
  payload = type(payload) == 'table' and payload or {}
  notify(payload.message, payload.type)
end)

RegisterNetEvent('mz_warns:client:received', function(payload)
  payload = type(payload) == 'table' and payload or {}
  notify(string.format(
    Config.Messages.Received,
    tostring(payload.staffName or 'Staff'),
    tostring(payload.publicId or '-'),
    tostring(payload.reason or 'Sem motivo')
  ), 'warning')
end)
