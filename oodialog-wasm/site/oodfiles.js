// oodfiles.js: Windows file names for ooRexx/WASM.
// Architecture: Tom Dyer.  Code: Claude (Fable 5.2).
//
// Windows programs name files in ::requires and CALL with "\" and without regard
// to case: ::requires "support\View.rex" finds Support/View.rex.  The WASM machine
// has a POSIX file system, where "support\View.rex" is one file name with a "\" in it.
// The interpreter cannot be changed from here, so this gives it that file: for every
// such name written in a program, the file it means is added once more under the
// literal name, in each directory from which the name resolves the Windows way.
// The same is done for data files a program names in a string (since 0.2.0).
// The programs stay unchanged.
//
//   files: { "/abs/path": string | Uint8Array, ... }   (the object given to rexx.run)
//   returns the number of names added; `files` is changed in place.
(function (root) {
  'use strict';
  const version = '0.2.0';
  function windowsNames(files) {
    const kids = new Map();                       // directory -> Map(lower-case name -> real name)
    const note = (dir, name) => { if (!kids.has(dir)) kids.set(dir, new Map()); kids.get(dir).set(name.toLowerCase(), name); };
    for (const p of Object.keys(files)) {
      const parts = p.split('/');                 // "", "home", "rexx", "a.rex"
      for (let i = 1; i < parts.length; i++) note(parts.slice(0, i).join('/') || '/', parts[i]);
    }
    const join = (dir, name) => (dir === '/' ? '/' + name : dir + '/' + name);
    const up = (dir) => { const i = dir.lastIndexOf('/'); return i <= 0 ? '/' : dir.slice(0, i); };
    const find = (dir, name) => { const m = kids.get(dir); return m ? m.get(name.toLowerCase()) : undefined; };
    function resolve(base, winName) {             // the real path, or null
      const parts = winName.split('\\');
      let dir = base;
      for (let i = 0; i < parts.length; i++) {
        const part = parts[i];
        if (part === '' || part === '.') continue;
        if (part === '..') { dir = up(dir); continue; }
        const last = (i === parts.length - 1);
        let real = find(dir, part);
        if (real === undefined && last) real = find(dir, part + '.rex') || find(dir, part + '.cls');
        if (real === undefined) return null;
        dir = join(dir, real);
      }
      return Object.prototype.hasOwnProperty.call(files, dir) ? dir : null;
    }
    const named = /(?:::requires|\bcall)\s+(["'])([^"'\r\n]+)\1/gi;
    const isProgram = (p) => /\.(rex|cls|rxo|frm|orx)$/i.test(p);
    const has = (p) => Object.prototype.hasOwnProperty.call(files, p) || Object.prototype.hasOwnProperty.call(add, p);
    const names = (p) => {                        // the file names a program requires or calls
      const text = files[p], out = [];
      if (typeof text !== 'string' || !isProgram(p)) return out;
      let m;
      named.lastIndex = 0;
      while ((m = named.exec(text)) !== null) out.push(m[2]);
      return out;
    };
    const add = {};
    // A file loaded under an added name sits, for the interpreter, in the directory
    // of that name, not in its own.  What it requires by a plain name from its own
    // directory must therefore be found there too: follow those names as well.
    function follow(base, real) {
      for (const name of names(real)) {
        const target = resolve(up(real), name) || resolve(base, name);
        const alias = join(base, name);
        if (target === null || target === alias || has(alias)) continue;
        add[alias] = files[target];
        follow(base, target);
      }
    }
    for (const p of Object.keys(files)) {
      for (const winName of names(p)) {
        if (winName.indexOf('\\') < 0) continue;      // a plain name: the interpreter finds it by itself
        for (let base = up(p); ; base = up(base)) {   // the program's directory, then each one above it
          const real = resolve(base, winName);
          const alias = join(base, winName);
          if (real !== null && real !== alias && !has(alias)) { add[alias] = files[real]; follow(base, real); }
          if (base === '/') break;
        }
      }
    }
    // Data files.  A program also opens files by names it writes as strings: "data\\Items.txt",
    // or "itemsI.inp" for the file ItemsI.INP.  Windows finds them whatever the case.  For each
    // string in a program that looks like a file name and means, the Windows way, a file that
    // exists under another spelling, that file is added under the spelling written, in the
    // program's directory.
    const literal = /(["'])([A-Za-z0-9_ .\\\/-]+\.[A-Za-z0-9]{1,5})\1/g;
    for (const p of Object.keys(files)) {
      const text = files[p];
      if (typeof text !== 'string' || !isProgram(p)) continue;
      let m;
      literal.lastIndex = 0;
      while ((m = literal.exec(text)) !== null) {
        const name = m[2].replace(/\//g, '\\');
        const real = resolve(up(p), name);
        const alias = join(up(p), m[2]);
        if (real !== null && real !== alias && !has(alias)) add[alias] = files[real];
      }
    }
    Object.assign(files, add);
    return Object.keys(add).length;
  }
  root.oodFiles = { version, windowsNames };
})(typeof window !== 'undefined' ? window : globalThis);
