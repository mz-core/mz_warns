MZWarns = MZWarns or {}
MZWarns.DB = MZWarns.DB or {}

local ready = false
local readyError = 'not_initialized'

local TABLE_STATEMENTS = {
  [[CREATE TABLE IF NOT EXISTS mz_warn_entries (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    public_id VARCHAR(16) NOT NULL,
    target_account_id BIGINT UNSIGNED NOT NULL,
    target_character_id INT UNSIGNED NULL,
    target_name VARCHAR(128) NOT NULL,
    reason VARCHAR(256) NOT NULL,
    issued_by_account_id BIGINT UNSIGNED NOT NULL,
    issued_by_character_id INT UNSIGNED NULL,
    issued_by_name VARCHAR(128) NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'active',
    revision BIGINT UNSIGNED NOT NULL DEFAULT 1,
    issued_at BIGINT UNSIGNED NOT NULL,
    revoked_at BIGINT UNSIGNED NULL,
    revoked_by_account_id BIGINT UNSIGNED NULL,
    revoked_by_character_id INT UNSIGNED NULL,
    revoked_by_name VARCHAR(128) NULL,
    revoke_reason VARCHAR(256) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_mz_warn_public_id (public_id),
    KEY idx_mz_warn_target_status (target_account_id, status, issued_at),
    KEY idx_mz_warn_status_issued (status, issued_at),
    KEY idx_mz_warn_target_name (target_name)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
  [[CREATE TABLE IF NOT EXISTS mz_warn_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    public_id VARCHAR(16) NOT NULL,
    entry_revision BIGINT UNSIGNED NOT NULL,
    action VARCHAR(32) NOT NULL,
    actor_source INT NULL,
    actor_account_id BIGINT UNSIGNED NOT NULL,
    actor_character_id INT UNSIGNED NULL,
    actor_name VARCHAR(128) NOT NULL,
    target_account_id BIGINT UNSIGNED NOT NULL,
    target_character_id INT UNSIGNED NULL,
    target_name VARCHAR(128) NOT NULL,
    previous_status VARCHAR(16) NULL,
    next_status VARCHAR(16) NOT NULL,
    reason VARCHAR(256) NOT NULL,
    created_at BIGINT UNSIGNED NOT NULL,
    UNIQUE KEY uq_mz_warn_audit_revision (public_id, entry_revision),
    KEY idx_mz_warn_audit_target (target_account_id, created_at),
    KEY idx_mz_warn_audit_action (action, created_at)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]
}

local function validateSchema()
  local ok, err = pcall(function()
    MySQL.single.await([[
      SELECT id, public_id, target_account_id, target_character_id, target_name, reason,
             issued_by_account_id, issued_by_character_id, issued_by_name, status, revision, issued_at,
             revoked_at, revoked_by_account_id, revoked_by_character_id, revoked_by_name, revoke_reason
      FROM mz_warn_entries
      LIMIT 1
    ]])
    MySQL.single.await([[
      SELECT id, public_id, entry_revision, action, actor_source,
             actor_account_id, actor_character_id, actor_name,
             target_account_id, target_character_id, target_name,
             previous_status, next_status, reason, created_at
      FROM mz_warn_audit
      LIMIT 1
    ]])
  end)
  return ok, ok and nil or tostring(err)
end

function MZWarns.DB.Initialize()
  ready = false
  readyError = 'initializing'
  if Config.Database and Config.Database.AutoCreateMissingTables == true then
    for _, statement in ipairs(TABLE_STATEMENTS) do
      local ok, err = pcall(MySQL.query.await, statement)
      if not ok then
        readyError = 'schema_create_failed:' .. tostring(err)
        return false, readyError
      end
    end
  end
  local valid, validationError = validateSchema()
  if not valid then
    readyError = 'schema_invalid:' .. tostring(validationError)
    return false, readyError
  end
  ready = true
  readyError = nil
  return true
end

function MZWarns.DB.IsReady()
  return ready, readyError
end

function MZWarns.DB.Get(publicId)
  return MySQL.single.await([[
    SELECT id, public_id, target_account_id, target_character_id, target_name, reason,
           issued_by_account_id, issued_by_character_id, issued_by_name, status, revision, issued_at,
           revoked_at, revoked_by_account_id, revoked_by_character_id, revoked_by_name, revoke_reason
    FROM mz_warn_entries
    WHERE public_id = ?
    LIMIT 1
  ]], { publicId })
end

function MZWarns.DB.Create(publicId, target, actor, reason, now)
  local statements = {
    {
      query = [[
        INSERT INTO mz_warn_entries
          (public_id, target_account_id, target_character_id, target_name, reason,
           issued_by_account_id, issued_by_character_id, issued_by_name, status, revision, issued_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active', 1, ?)
      ]],
      parameters = {
        publicId,
        target.accountId,
        target.characterId,
        target.name,
        reason,
        actor.accountId,
        actor.characterId,
        actor.name,
        now
      }
    },
    {
      query = [[
        INSERT INTO mz_warn_audit
          (public_id, entry_revision, action, actor_source, actor_account_id,
           actor_character_id, actor_name, target_account_id, target_character_id, target_name, previous_status,
           next_status, reason, created_at)
        VALUES (?, 1, 'issued', ?, ?, ?, ?, ?, ?, ?, NULL, 'active', ?, ?)
      ]],
      parameters = {
        publicId,
        actor.source,
        actor.accountId,
        actor.characterId,
        actor.name,
        target.accountId,
        target.characterId,
        target.name,
        reason,
        now
      }
    }
  }
  if MySQL.transaction.await(statements) ~= true then
    local lookupOk, existing = pcall(MZWarns.DB.Get, publicId)
    if lookupOk and existing then return nil, 'public_id_collision' end
    return nil, 'persistence_failed'
  end
  return MZWarns.DB.Get(publicId)
end

function MZWarns.DB.List(filters)
  filters = type(filters) == 'table' and filters or {}
  local clauses = {}
  local parameters = {}
  if filters.status then
    clauses[#clauses + 1] = 'status = ?'
    parameters[#parameters + 1] = filters.status
  end
  if filters.targetAccountId then
    clauses[#clauses + 1] = 'target_account_id = ?'
    parameters[#parameters + 1] = filters.targetAccountId
  end
  if filters.search then
    clauses[#clauses + 1] = '(public_id LIKE ? OR target_name LIKE ? OR CAST(target_account_id AS CHAR) LIKE ?)'
    parameters[#parameters + 1] = '%' .. filters.search .. '%'
    parameters[#parameters + 1] = '%' .. filters.search .. '%'
    parameters[#parameters + 1] = '%' .. filters.search .. '%'
  end
  local where = #clauses > 0 and (' WHERE ' .. table.concat(clauses, ' AND ')) or ''
  local countRow = MySQL.single.await(
    'SELECT COUNT(1) AS total FROM mz_warn_entries' .. where,
    parameters
  )
  local queryParameters = {}
  for index = 1, #parameters do queryParameters[index] = parameters[index] end
  queryParameters[#queryParameters + 1] = filters.pageSize
  queryParameters[#queryParameters + 1] = filters.offset
  local rows = MySQL.query.await([[
    SELECT id, public_id, target_account_id, target_character_id, target_name, reason,
           issued_by_account_id, issued_by_character_id, issued_by_name, status, revision, issued_at,
           revoked_at, revoked_by_account_id, revoked_by_character_id, revoked_by_name, revoke_reason
    FROM mz_warn_entries
  ]] .. where .. [[
    ORDER BY issued_at DESC, id DESC
    LIMIT ? OFFSET ?
  ]], queryParameters) or {}
  return rows, tonumber(countRow and countRow.total) or 0
end

function MZWarns.DB.Revoke(entry, actor, reason, now)
  local previousRevision = math.max(1, tonumber(entry.revision) or 1)
  local nextRevision = previousRevision + 1
  local statements = {
    {
      query = [[
        UPDATE mz_warn_entries
        SET status = 'revoked', revision = ?, revoked_at = ?,
            revoked_by_account_id = ?, revoked_by_character_id = ?, revoked_by_name = ?, revoke_reason = ?
        WHERE id = ? AND status = 'active' AND revision = ?
      ]],
      parameters = {
        nextRevision,
        now,
        actor.accountId,
        actor.characterId,
        actor.name,
        reason,
        entry.id,
        previousRevision
      }
    },
    {
      query = [[
        INSERT INTO mz_warn_audit
          (public_id, entry_revision, action, actor_source, actor_account_id,
           actor_character_id, actor_name, target_account_id, target_character_id, target_name, previous_status,
           next_status, reason, created_at)
        SELECT public_id, revision, 'revoked', ?, ?, ?, ?, target_account_id,
               target_character_id, target_name, 'active', 'revoked', ?, ?
        FROM mz_warn_entries
        WHERE id = ? AND status = 'revoked' AND revision = ?
      ]],
      parameters = {
        actor.source,
        actor.accountId,
        actor.characterId,
        actor.name,
        reason,
        now,
        entry.id,
        nextRevision
      }
    }
  }
  if MySQL.transaction.await(statements) ~= true then return nil, 'persistence_failed' end
  local updated = MZWarns.DB.Get(entry.public_id)
  if not updated
    or tostring(updated.status) ~= 'revoked'
    or tonumber(updated.revision) ~= nextRevision then
    return nil, 'revision_conflict'
  end
  return updated
end
