/* OodBroker.cls -- the editors' secret store as a provider for the estate's
   Secret Broker, for the plugins that call out (assist, git, ssc).
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   The store is OodSecrets (OodPlugins.cls): this page's memory, never saved,
   never shown again.  A plugin names a secret by its reference; the broker
   hands it out as a lease, and only to a trusted consumer, as the estate's
   transports take theirs.  This is the session secret provider; a provider
   brokered by a server can stand in its place behind the same
   SecretProviderBase (OodSecrets~provider). */

::requires "SecretBroker.cls"

::class OodSecretsProvider public subclass SecretProviderBase
::method init
  expose store
  use strict arg store
  self~init:super
::method resolve
  expose store
  use strict arg reference
  if \store~has(reference) then return .SecretProviderResult~new(.false, "", "SECRET_NOT_FOUND")
  return .SecretProviderResult~new(.true, store~acquire(reference), "")
::method module_version class
  return "0.8.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.8.0"
::method module_lastChanged
  return "2026-11-15"

/* A plugin's way to a secret: a broker over the host's store (or the provider
   the store names), one lease, retired at once.  Answers the value, or .nil
   when it is not there; the caller puts it into a header and drops it. */
::class OodSecretUse public
::method value class
  use strict arg host, reference
  lease = self~broker(host)~acquire(reference)
  r = lease~secretForTrustedConsumer
  lease~retire
  if \r~ok then return .nil
  return r~value
-- the broker: over the provider OodSecrets names, if one is set, else the store
::method broker class
  use strict arg host
  provider = host~secrets~class~provider
  if \provider~isA(.SecretProviderBase) then provider = .OodSecretsProvider~new(host~secrets)
  return .SecretBroker~new(provider)
::method module_version class
  return "0.8.0"
::method module_lastChanged class
  return "2026-11-15"
