Config = {}

Config.Version = '1.0.0'
Config.AutoPunishment = false

Config.Database = {
  AutoCreateMissingTables = true
}

Config.Commands = {
  Issue = 'warn',
  List = 'warns',
  Revoke = 'unwarn'
}

Config.Integration = {
  CoreResource = 'mz_core',
  TrustedResources = {
    mz_admin = true,
    mz_warns = true
  },
  Permissions = {
    View = 'staff.warns.view',
    Issue = 'staff.warns.issue',
    Revoke = 'staff.warns.revoke'
  },
  Limits = {
    PageSize = 25,
    MaxPageSize = 50,
    ReasonMin = 3,
    ReasonMax = 256,
    SearchMax = 80
  }
}

Config.Messages = {
  Received = 'Voce recebeu uma advertencia de %s. Codigo: %s. Motivo: %s',
  Issued = 'Advertencia registrada: %s',
  Revoked = 'Advertencia revogada: %s',
  UsageIssue = 'Uso: /warn [id] [motivo]',
  UsageList = 'Uso: /warns [id]',
  UsageRevoke = 'Uso: /unwarn [MWR-XXXXXXXX] [motivo]'
}
