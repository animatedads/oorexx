/* AssistPlugin.cls -- an optional extra for the ooDialog Designer and the
   ooRexx Object Editor: code assistance from a language model, through the
   estate's own brokerage.  Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   German: Claude (Opus 5.5).

   Well behaved, by these rules:
   - it proposes; it never changes the code itself.  The page shows the
     proposal beside the code and the person applies it, or not;
   - a proposal can be applied only when it compiles as a method body
     (.Method~new), has none of Boston Crab's pitfalls (RexxPitfallChecker)
     and has no :: directive lines; otherwise it is shown with the reasons;
   - the model is told the context (the design, the method) and the rules, and
     asked for the method body only, in one ```rexx block;
   - the cost of each proposal is shown (Anthropic's rate card; token counts
     for an OpenAI-compatible model);
   - keys: the person gives them in the plugin's settings; they go to the
     editor's secret store (OodSecrets: this page's memory, never saved,
     never shown again), which the plugins hand to the estate's Secret
     Broker as its provider (OodSecretsProvider, plugins/common/OodBroker.cls).
     The providers acquire a lease by reference, as the estate's curl
     transports do; their fetch transports set the key as a header from a
     variable and drop it after the request (oorexx_ai_provider_anthropic v0.5, openai_compat v0.6).

   Providers: Anthropic (AnthropicFetchMessageClient, Haiku 5.5 unless the
   settings say otherwise) or an OpenAI-compatible endpoint
   (OpenAICompatProviderAdapter over OpenAICompatFetchTransport). */

::requires "OodPlugins.cls"
::requires "PitfallChecker.cls"
::requires "AnthropicMessages.cls"
::requires "AnthropicProvider.cls"
::requires "OpenAICompatProvider.cls"
::requires "SecretBroker.cls"
::requires "OodBroker.cls"

::class AssistPlugin public subclass OodPlugin
::method module_version class
  return "0.8.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.8.0"
::method module_lastChanged
  return "2026-11-15"

::method init
  use strict arg id
  self~init:super(id)
  -- the secrets' names (references) in the editor's store
  self~setSetting("anthropic.key", "ASSIST.ANTHROPIC.KEY")
  self~setSetting("openai.key", "ASSIST.OPENAI.KEY")
  self~setSetting("provider", "anthropic")
  self~setSetting("anthropic.model", "claude-haiku-5-5")
  self~setSetting("openai.endpoint", "https://api.openai.com/v1/chat/completions")
  self~setSetting("maxTokens", "1024")

::method resources
  return .resources

::method provides
  return "assist"

::method settingLines
  out = .array~new
  out~append("provider" || "09"x || "choice:anthropic|openai" || "09"x || self~nls("set.provider"))
  out~append("anthropic.key" || "09"x || "secret" || "09"x || self~nls("set.anthropicKey"))
  out~append("anthropic.model" || "09"x || "text" || "09"x || self~nls("set.anthropicModel"))
  out~append("anthropic.url" || "09"x || "text" || "09"x || self~nls("set.anthropicUrl"))
  out~append("openai.key" || "09"x || "secret" || "09"x || self~nls("set.openaiKey"))
  out~append("openai.model" || "09"x || "text" || "09"x || self~nls("set.openaiModel"))
  out~append("openai.endpoint" || "09"x || "text" || "09"x || self~nls("set.openaiEndpoint"))
  out~append("maxTokens" || "09"x || "text" || "09"x || self~nls("set.maxTokens"))
  return out~makeString("L", "0a"x)

-- A proposal for the code, for this task.  Answers a directory: STATUS (ok,
-- refused: shown but not to be applied, failed: no proposal), CODE, NOTES
-- (lines), MODEL, COST.
::method propose
  use strict arg task, code, context
  r = .directory~new
  r["STATUS"] = "failed"; r["CODE"] = ""; r["NOTES"] = .array~new; r["MODEL"] = ""; r["COST"] = ""
  if task~strip == "" then do
    r["NOTES"]~append(self~nls("err.noTask"))
    return r
  end
  prompt = self~promptFor(task, code, context)
  provider = self~setting("provider")~lower
  keyName = "anthropic.key"; keyLabel = "set.anthropicKey"
  if provider == "openai" then do; keyName = "openai.key"; keyLabel = "set.openaiKey"; end
  if \self~host~secrets~has(self~setting(keyName)) then do
    r["NOTES"]~append(self~nls("err.noKey", self~nls(keyLabel)))
    return r
  end
  broker = .OodSecretUse~broker(self~host)
  max = self~setting("maxTokens", 1024)
  if \datatype(max, "W") then max = 1024
  if provider == "openai" then answer = self~askOpenAI(broker, prompt, max, r)
  else answer = self~askAnthropic(broker, prompt, max, r)
  if answer == .nil then return r
  proposal = codeBlockOf(answer)
  r["CODE"] = proposal
  -- what it must pass before it can be applied
  lines = proposal~makeArray("0a"x)
  do l over lines
    if l~strip~left(2) == "::" then r["NOTES"]~append(self~nls("chk.directive"))
  end
  err = compileError(lines)
  if err \== "" then r["NOTES"]~append(self~nls("chk.compile", err))
  do p over .RexxPitfallChecker~new~check(lines)
    r["NOTES"]~append(self~nls("chk.pitfall", p~rule, p~line))
  end
  if r["NOTES"]~items = 0 then r["STATUS"] = "ok"
  else r["STATUS"] = "refused"
  return r

::method promptFor
  use strict arg task, code, context
  t = self~nls("prompt.rules")~changeStr("\n", "0a"x)
  t = t || "0a"x || "0a"x || "Context:" || "0a"x || context
  t = t || "0a"x || "0a"x || "The method body now:" || "0a"x || "```rexx" || "0a"x || code || "0a"x || "```"
  t = t || "0a"x || "0a"x || "Task:" || "0a"x || task
  return t

::method askAnthropic
  use strict arg broker, prompt, max, r
  model = self~setting("anthropic.model", "claude-haiku-5-5")
  cfg = .AnthropicRuntimeConfig~new(.AnthropicChannel~direct, broker, self~setting("anthropic.key"), model, max, 60)
  client = .AnthropicFetchMessageClient~new(cfg, self~setting("anthropic.url", ""))
  req = .AnthropicMessageRequest~new(model, "", .false, max)
  req~thinkingOff
  req~addText(prompt)
  reply = client~send(req)
  r["MODEL"] = reply~model
  if \reply~ok then do
    r["NOTES"]~append(self~nls("err.provider", reply~code, reply~message))
    return .nil
  end
  cost = reply~costUsd(.AnthropicModelCatalog~new)
  if cost \== "" then r["COST"] = "$" || format(cost, , 6) "(" || reply~inputTokens "in," reply~outputTokens "out)"
  else r["COST"] = reply~inputTokens "in," reply~outputTokens "out"
  return reply~text

::method askOpenAI
  use strict arg broker, prompt, max, r
  model = self~setting("openai.model", "")
  if model == "" then do
    r["NOTES"]~append(self~nls("err.noModel"))
    return .nil
  end
  endpoint = self~setting("openai.endpoint")
  config = .OpenAICompatProviderConfig~new(endpoint, self~setting("openai.key"), .array~of(model), 60, endpoint~left(7)~caselessEquals("http://"), max)
  adapter = .OpenAICompatProviderAdapter~new(config, broker, .OpenAICompatFetchTransport~new(endpoint~left(7)~caselessEquals("http://")))
  reply = adapter~complete(.AIProviderRequest~new(model, prompt, max))
  r["MODEL"] = reply~model
  if \reply~ok then do
    r["NOTES"]~append(self~nls("err.provider", reply~code, reply~detail))
    return .nil
  end
  if reply~usage \== .nil then r["COST"] = reply~usage~inputTokens "in," reply~usage~outputTokens "out"
  return reply~text


-- the code of the first ```rexx (or ```) block, or the whole answer
::routine codeBlockOf
  use strict arg text
  text = text~changeStr("0d0a"x, "0a"x)
  p = text~pos("```")
  if p = 0 then return text~strip("T", "0a"x)
  q = text~pos("0a"x, p)
  if q = 0 then return ""
  e = text~pos("```", q)
  if e = 0 then e = text~length + 1
  return text~substr(q + 1, e - q - 1)~strip("T", "0a"x)

-- "" when the lines compile as a method body, else the error
::routine compileError
  use strict arg lines
  signal on syntax name bad
  m = .Method~new("proposal", lines)
  return ""
bad:
  c = condition("O")
  msg = c~at("ERRORTEXT")
  if c~at("ADDITIONAL") \== .nil, c~at("ADDITIONAL")~items > 0 then msg = c~at("MESSAGE")
  return "line" c~at("POSITION")":" msg

::resource strings.en
set.provider = Provider (anthropic or openai)
set.anthropicKey = Anthropic API key
set.anthropicModel = Anthropic model
set.anthropicUrl = Anthropic address (empty: https://api.anthropic.com)
set.openaiKey = OpenAI API key
set.openaiModel = OpenAI model
set.openaiEndpoint = OpenAI-compatible endpoint
set.maxTokens = Most tokens in an answer
err.noTask = Say what the code should do.
err.noModel = Give the OpenAI model in the plugin's settings.
err.noKey = No key: give the %1 in the plugin's settings.
err.provider = The provider answered %1: %2
chk.directive = A line starts with :: (a directive): a method body has none.
chk.compile = It does not compile: %1
chk.pitfall = Boston Crab: %1 on line %2.
prompt.rules = You help write ooRexx 5 code: the body of one method, in the ooDialog Designer or the ooRexx Object Editor.\nAnswer with the complete new method body only, in one ```rexx block, and nothing else.\nWrite no :: directives.  Use only the names in the context; a control is self~name.\nJoin a string and a value with ||: never put a string right before ( or before x or b.\nNever use a loop variable with the name of a "use arg" argument.  Names differing only in case are one name.\nKeep the existing lines unless the task says otherwise.\nIf the task is unclear, or needs what the context does not have, answer with the code as it is and a -- comment saying what is missing.
::END

::resource strings.de
-- Deutsch: übersetzt von Claude (Opus 5.5); bitte von einem Muttersprachler prüfen
set.provider = Anbieter (anthropic oder openai)
set.anthropicKey = Anthropic-API-Schlüssel
set.anthropicModel = Anthropic-Modell
set.anthropicUrl = Anthropic-Adresse (leer: https://api.anthropic.com)
set.openaiKey = OpenAI-API-Schlüssel
set.openaiModel = OpenAI-Modell
set.openaiEndpoint = OpenAI-kompatibler Endpunkt
set.maxTokens = Höchstzahl Token einer Antwort
err.noTask = Sagen, was der Code tun soll.
err.noModel = Das OpenAI-Modell in den Einstellungen des Plugins angeben.
err.noKey = Kein Schlüssel: den %1 in den Einstellungen des Plugins angeben.
err.provider = Der Anbieter antwortete %1: %2
chk.directive = Eine Zeile beginnt mit :: (eine Direktive): ein Methodenrumpf hat keine.
chk.compile = Es lässt sich nicht übersetzen: %1
chk.pitfall = Boston Crab: %1 in Zeile %2.
prompt.rules = You help write ooRexx 5 code: the body of one method, in the ooDialog Designer or the ooRexx Object Editor.\nAnswer with the complete new method body only, in one ```rexx block, and nothing else.\nWrite no :: directives.  Use only the names in the context; a control is self~name.\nJoin a string and a value with ||: never put a string right before ( or before x or b.\nNever use a loop variable with the name of a "use arg" argument.  Names differing only in case are one name.\nKeep the existing lines unless the task says otherwise.\nIf the task is unclear, or needs what the context does not have, answer with the code as it is and a -- comment saying what is missing.\nThe person writes in German; comments in the code may be German.
::END
