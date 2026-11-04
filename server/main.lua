CreateThread(function()
  local ok, err = MZWarns.DB.Initialize()
  if ok then
    print('[mz_warns] ready autoPunishment=false')
    return
  end
  print(('[mz_warns] unavailable error=%s'):format(tostring(err)))
end)
