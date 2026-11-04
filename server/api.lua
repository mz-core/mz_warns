MZWarns = MZWarns or {}
MZWarns.API = MZWarns.API or {}

local function result(ok, data, err)
  return {
    ok = ok == true,
    data = ok == true and data or nil,
    error = ok == true and nil or tostring(err or 'unknown_error')
  }
end

local function integration()
  return type(Config.Integration) == 'table' and Config.Integration or {}
end

local function limits()
  return type(integration().Limits) == 'table' and integration().Limits or {}
end

local function trusted(resourceName)
  local resources = integration().TrustedResources
  return type(resourceName) == 'string'
    and type(resources) == 'table'
    and resources[resourceName] == true
end

local function sanitizeText(value, maxLength)
  if type(value) ~= 'string' then return '' end
  value = value:gsub('%c', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  maxLength = math.max(1, tonumber(maxLength) or 128)
  return #value > maxLength and value:sub(1, maxLength) or value
end

local function sanitizePublicId(value)
  if type(value) ~= 'string' then return nil end
  value = value:upper():gsub('%s+', '')
  if not value:match('^MWR%-[A-HJ-NP-Z2-9][A-HJ-NP-Z2-9][A-HJ-NP-Z2-9][A-HJ-NP-Z2-9][A-HJ-NP-Z2-9][A-HJ-NP-Z2-9][A-HJ-NP-Z2-9][A-HJ-NP-Z2-9]$') then
    return nil
  end
  return value
end

local function publicId()
  local alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  local value = {}
  for index = 1, 8 do
    local position = math.random(1, #alphabet)
    value[index] = alphabet:sub(position, position)
  end
  return 'MWR-' .. table.concat(value)
end

local function coreResource()
  return tostring(integration().CoreResource or 'mz_core')
end

local function authorize(actorSource, permission)
  actorSource = tonumber(actorSource)
  if not actorSource or actorSource <= 0 or not GetPlayerName(actorSource) then
    return false, 'invalid_actor'
  end
  if GetResourceState(coreResource()) ~= 'started' then return false, 'core_unavailable' end
  local ok, allowed = pcall(function()
    return exports[coreResource()]:HasGlobalPermission(actorSource, permission)
  end)
  if not ok then return false, 'authorization_unavailable' end
  return allowed == true, allowed == true and nil or 'permission_denied'
end

local function resolveIdentity(sourceId)
  local ok, identity = pcall(function()
    return exports[coreResource()]:ResolvePlayerIdentity(sourceId)
  end)
  if not ok or type(identity) ~= 'table' or identity.ok ~= true then
    return nil, identity and identity.error or 'identity_unavailable'
  end
  local accountId = tonumber(identity.accountId)
  local characterId = tonumber(identity.characterId)
  if not accountId or not characterId then return nil, 'identity_unavailable' end
  local fullName = sanitizeText(
    table.concat({ tostring(identity.firstname or ''), tostring(identity.lastname or '') }, ' '),
    128
  )
  return {
    source = tonumber(sourceId),
    accountId = accountId,
    characterId = characterId,
    name = fullName ~= '' and fullName or sanitizeText(GetPlayerName(sourceId), 128)
  }
end

local function dto(entry)
  return {
    publicId = entry.public_id,
    targetName = entry.target_name,
    accountId = tonumber(entry.target_account_id),
    characterId = tonumber(entry.target_character_id),
    reason = entry.reason,
    issuedByName = entry.issued_by_name,
    status = entry.status,
    revision = tonumber(entry.revision),
    issuedAt = tonumber(entry.issued_at),
    revokedAt = tonumber(entry.revoked_at),
    revokedByName = entry.revoked_by_name,
    revokeReason = entry.revoke_reason
  }
end

local function auditGlobal(actorSource, action, entry, reason)
  if GetResourceState(coreResource()) ~= 'started' then return end
  pcall(function()
    exports[coreResource()]:CreateDetailedLog('admin', 'admin.warn.' .. action, {
      actor = {
        type = 'player',
        source = actorSource,
        name = GetPlayerName(actorSource)
      },
      target = {
        type = 'player',
        name = entry.target_name
      },
      context = {
        resource = 'mz_warns',
        decision = action
      },
      meta = {
        publicId = entry.public_id,
        status = entry.status,
        reason = reason
      }
    })
  end)
end

local function dbCall(operation, ...)
  local handler = MZWarns.DB and MZWarns.DB[operation]
  if type(handler) ~= 'function' then return false, nil, 'database_unavailable' end
  local ok, first, second = pcall(handler, ...)
  if not ok then
    print(('[mz_warns] database operation=%s error=%s'):format(
      tostring(operation),
      tostring(first)
    ))
    return false, nil, 'persistence_failed'
  end
  return true, first, second
end

function MZWarns.API.IsReady()
  return MZWarns.DB.IsReady()
end

function MZWarns.API.Issue(actorSource, targetSource, reason, invokingResource)
  if not trusted(invokingResource) then return result(false, nil, 'untrusted_resource') end
  local permission = integration().Permissions and integration().Permissions.Issue
  local allowed, authError = authorize(actorSource, permission)
  if not allowed then return result(false, nil, authError) end
  local databaseReady, databaseError = MZWarns.DB.IsReady()
  if databaseReady ~= true then return result(false, nil, databaseError) end

  targetSource = tonumber(targetSource)
  if not targetSource or targetSource <= 0 or not GetPlayerName(targetSource) then
    return result(false, nil, 'invalid_target')
  end
  if tonumber(actorSource) == targetSource then return result(false, nil, 'self_target') end

  local hierarchyOk, hierarchyAllowed, hierarchyReason = pcall(function()
    return exports[coreResource()]:CanStaffActOnPlayer(actorSource, targetSource)
  end)
  if not hierarchyOk then return result(false, nil, 'hierarchy_unavailable') end
  if hierarchyAllowed ~= true then return result(false, nil, hierarchyReason or 'hierarchy_denied') end

  reason = sanitizeText(reason, limits().ReasonMax or 256)
  if #reason < math.max(1, tonumber(limits().ReasonMin) or 3) then
    return result(false, nil, 'invalid_reason')
  end

  local actor, actorError = resolveIdentity(actorSource)
  if not actor then return result(false, nil, actorError) end
  local target, targetError = resolveIdentity(targetSource)
  if not target then return result(false, nil, targetError) end

  local entry, createError
  for _ = 1, 3 do
    local createOk
    createOk, entry, createError = dbCall('Create', publicId(), target, actor, reason, os.time())
    if not createOk then return result(false, nil, createError) end
    if entry or createError ~= 'public_id_collision' then break end
  end
  if not entry then return result(false, nil, createError or 'persistence_failed') end

  auditGlobal(actorSource, 'issued', entry, reason)
  TriggerClientEvent('mz_warns:client:received', targetSource, {
    publicId = entry.public_id,
    reason = entry.reason,
    staffName = entry.issued_by_name
  })
  return result(true, { warning = dto(entry) })
end

function MZWarns.API.List(actorSource, filters, invokingResource)
  if not trusted(invokingResource) then return result(false, nil, 'untrusted_resource') end
  local permission = integration().Permissions and integration().Permissions.View
  local allowed, authError = authorize(actorSource, permission)
  if not allowed then return result(false, nil, authError) end
  local databaseReady, databaseError = MZWarns.DB.IsReady()
  if databaseReady ~= true then return result(false, nil, databaseError) end

  filters = type(filters) == 'table' and filters or {}
  local status = type(filters.status) == 'string' and filters.status:lower() or nil
  if status ~= nil and status ~= 'active' and status ~= 'revoked' then
    return result(false, nil, 'invalid_status')
  end

  local targetAccountId
  if filters.targetSource ~= nil then
    local targetSource = tonumber(filters.targetSource)
    if not targetSource or not GetPlayerName(targetSource) then
      return result(false, nil, 'invalid_target')
    end
    local target, targetError = resolveIdentity(targetSource)
    if not target then return result(false, nil, targetError) end
    targetAccountId = target.accountId
  end

  local search = sanitizeText(filters.search, limits().SearchMax or 80)
  if search == '' then search = nil end
  local page = math.max(1, math.floor(tonumber(filters.page) or 1))
  local pageSize = math.min(
    math.max(1, tonumber(limits().MaxPageSize) or 50),
    math.max(1, math.floor(tonumber(filters.pageSize) or tonumber(limits().PageSize) or 25))
  )
  local listOk, rows, total = dbCall('List', {
    status = status,
    targetAccountId = targetAccountId,
    search = search,
    pageSize = pageSize,
    offset = (page - 1) * pageSize
  })
  if not listOk then return result(false, nil, total) end
  local items = {}
  for _, entry in ipairs(rows) do items[#items + 1] = dto(entry) end
  return result(true, {
    items = items,
    total = total,
    page = page,
    pageSize = pageSize
  })
end

function MZWarns.API.Revoke(actorSource, publicIdValue, reason, invokingResource)
  if not trusted(invokingResource) then return result(false, nil, 'untrusted_resource') end
  local permission = integration().Permissions and integration().Permissions.Revoke
  local allowed, authError = authorize(actorSource, permission)
  if not allowed then return result(false, nil, authError) end
  local databaseReady, databaseError = MZWarns.DB.IsReady()
  if databaseReady ~= true then return result(false, nil, databaseError) end

  publicIdValue = sanitizePublicId(publicIdValue)
  if not publicIdValue then return result(false, nil, 'invalid_public_id') end
  reason = sanitizeText(reason, limits().ReasonMax or 256)
  if #reason < math.max(1, tonumber(limits().ReasonMin) or 3) then
    return result(false, nil, 'invalid_reason')
  end

  local getOk, entry, getError = dbCall('Get', publicIdValue)
  if not getOk then return result(false, nil, getError) end
  if not entry then return result(false, nil, 'not_found') end
  if tostring(entry.status) ~= 'active' then return result(false, nil, 'already_revoked') end
  local actor, actorError = resolveIdentity(actorSource)
  if not actor then return result(false, nil, actorError) end

  local revokeOk, updated, revokeError = dbCall('Revoke', entry, actor, reason, os.time())
  if not revokeOk then return result(false, nil, revokeError) end
  if not updated then return result(false, nil, revokeError) end
  auditGlobal(actorSource, 'revoked', updated, reason)
  return result(true, { warning = dto(updated) })
end

exports('IsReady', function()
  return MZWarns.API.IsReady()
end)

exports('Issue', function(actorSource, targetSource, reason)
  return MZWarns.API.Issue(actorSource, targetSource, reason, GetInvokingResource())
end)

exports('List', function(actorSource, filters)
  return MZWarns.API.List(actorSource, filters, GetInvokingResource())
end)

exports('Revoke', function(actorSource, publicIdValue, reason)
  return MZWarns.API.Revoke(actorSource, publicIdValue, reason, GetInvokingResource())
end)
