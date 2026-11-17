// assist_mock_server.mjs -- a local stand-in for api.anthropic.com's
// /v1/messages and an OpenAI-compatible /v1/chat/completions, for
// tests/t07_assist.rex (ooRexx/WASM in Node) and the browser scenario in
// tools/dztest.py.  It answers CORS preflights, as the real APIs do for a
// page, and chooses its answer by the task's word:
//   GOOD       a method body that compiles and passes Boston Crab
//   TRAP       a Boston Crab P1 ("say '['(n)']'")
//   BROKEN     a body that does not compile
//   DIRECTIVE  a body with a :: line
//   PROSE      no ``` block: the whole answer is the code
//   DOCOK      an ooRexxDoc comment (the DOC kind; also an empty task, which
//              the plugin turns into "Write the ooRexxDoc comment ...")
//   DOCNOT     a plain /* */ comment, not a doc-comment
//   DOCTWO     two doc-comments in one answer
// It records each request's key header (/seen), so a test can see the key is
// sent once and not with a later request.
// Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
// usage: node assist_mock_server.mjs PORT
import http from 'node:http';
const port = Number(process.argv[2] || 8973);
const seen = [];
const ANTHROPIC_KEY = 'FAKE-ANTHROPIC-KEY-51', OPENAI_KEY = 'FAKE-OPENAI-KEY-62';
const answers = {
  DOCOK: 'The comment:\n```rexx\n/** Answers the sum of 1 to n.\n *\n * @param n  how far to count\n * @return the sum\n */\n```\n',
  DOCNOT: '```rexx\n/* Sums. */\n```',
  DOCTWO: '```rexx\n/** Sums. */\n/** Again. */\n```',
  GOOD: 'Here is the method.\n```rexx\nuse arg n\ntotal = 0\ndo i = 1 to n\n  total = total + i\nend\nself~lblTotal~setText("Total:" total)\n```\n',
  TRAP: '```rexx\nuse arg n\nsay "["(n)"]"\n```',
  BROKEN: '```rexx\nif then\n  say "x"\nend\n```',
  DIRECTIVE: '```rexx\nsay "hi"\n::method other\n  return 1\n```',
  PROSE: 'say "prose"',
};
function answerFor(prompt) {
  const task = String(prompt).split('Task:').pop();
  if (task.includes('ooRexxDoc comment for this member')) return answers.DOCOK;
  for (const k of Object.keys(answers)) if (task.includes(k)) return answers[k];
  return answers.GOOD;
}
function cors(res) {
  res.setHeader('access-control-allow-origin', '*');
  res.setHeader('access-control-allow-headers', '*');
  res.setHeader('access-control-allow-methods', 'POST, GET, OPTIONS');
}
http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => { body += c; });
  req.on('end', () => {
    cors(res);
    if (req.method === 'OPTIONS') { res.statusCode = 204; res.end(); return; }
    const h = req.headers;
    res.setHeader('content-type', 'application/json');
    if (req.url === '/seen') { res.end(JSON.stringify(seen)); return; }
    seen.push({ path: req.url, key: h['x-api-key'] || '', auth: h['authorization'] || '', browser: h['anthropic-dangerous-direct-browser-access'] || '' });
    let parsed = {}; try { parsed = JSON.parse(body); } catch (e) { /* bad body */ }
    if (req.url === '/v1/messages' && req.method === 'POST') {
      if (h['x-api-key'] !== ANTHROPIC_KEY) {
        res.statusCode = 401;
        res.end(JSON.stringify({ type: 'error', error: { type: 'authentication_error', message: 'invalid x-api-key' } }));
        return;
      }
      const prompt = ((parsed.messages || [])[0] || {}).content;
      const text = Array.isArray(prompt) ? prompt.map((b) => b.text || '').join('') : String(prompt || '');
      res.end(JSON.stringify({ id: 'msg_1', type: 'message', model: parsed.model, stop_reason: 'end_turn',
        content: [{ type: 'text', text: answerFor(text) }],
        usage: { input_tokens: 400, output_tokens: 60, cache_creation_input_tokens: 0, cache_read_input_tokens: 0 } }));
      return;
    }
    if (req.url === '/v1/chat/completions' && req.method === 'POST') {
      if (h['authorization'] !== 'Bearer ' + OPENAI_KEY) {
        res.statusCode = 401;
        res.end(JSON.stringify({ error: { message: 'Incorrect API key provided', type: 'invalid_request_error' } }));
        return;
      }
      const msgs = parsed.messages || [];
      const text = String((msgs[msgs.length - 1] || {}).content || '');
      res.end(JSON.stringify({ id: 'chat_1', object: 'chat.completion', model: parsed.model + '-actual',
        choices: [{ index: 0, finish_reason: 'stop', message: { role: 'assistant', content: answerFor(text) } }],
        usage: { prompt_tokens: 300, completion_tokens: 50, total_tokens: 350 } }));
      return;
    }
    res.statusCode = 404; res.end('{}');
  });
}).listen(port, '127.0.0.1');
